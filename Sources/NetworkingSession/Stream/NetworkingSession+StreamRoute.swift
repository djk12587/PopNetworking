//
//  NetworkingSession+StreamRoute.swift
//  PopNetworking
//

import Foundation

@available(iOS 15, macOS 12, tvOS 15, watchOS 8, visionOS 1, *)
public extension NetworkingSession {

    /// Performs a streaming HTTP request and returns the typed chunk stream.
    ///
    /// Lifecycle:
    /// 1. Builds the `URLRequest` — (``NetworkingEndpoint/urlRequest``)
    /// 2. Adapts the `URLRequest` — (``NetworkingHooks/adapter``)
    /// 3. (If ``NetworkingStreamRoute/mockChunks`` is non-empty) short-circuits the network and synthesizes a byte stream.
    /// 4. Notifies observers — (``NetworkingTransportObserver/willSend(urlRequest:)``)
    /// 5. Executes the request via ``URLSessionProtocol/bytes(for:byteChunkSize:)``
    /// 6. Runs the serializer — (``NetworkingStreamSerializer/stream(byteStream:urlResponse:)``). A synchronous throw here triggers connect-time retry.
    /// 7. On success, fires ``NetworkingTransportObserver/willBeginStream(urlRequest:urlResponse:)`` and returns the wrapped chunk stream.
    /// 8. The wrapped stream fires ``NetworkingTransportObserver/didFinishStream(urlRequest:urlResponse:error:)`` when iteration ends (clean EOF, mid-stream error, or consumer cancellation).
    ///
    /// Retriers run only at connect time (before any chunk is yielded). Mid-stream errors
    /// propagate through the returned stream and do not trigger the retrier.
    /// - Parameter route: The ``NetworkingStreamRoute`` to execute.
    /// - Returns: A typed `AsyncThrowingStream` of chunks.
    func executeStream<ResponseRoute: NetworkingStreamRoute>(route: ResponseRoute) async throws -> AsyncThrowingStream<ResponseRoute.Serializer.Chunk, Error> {

        let streamTask = StreamRouteTask(route: route)
        let sessionAdapter = self.adapter
        let sessionRetrier = self.retrier
        let sessionObservers = self.observers

        // Connect-attempt loop. Each iteration produces a `Result` from a single connect
        // attempt; success returns a stream to the caller and ends the loop. Failures are
        // funneled through one `consultRetriers` call — mirroring the response path's shape
        // where every error converges into a single `Result<SerializedObject, Error>` before
        // the retrier is consulted.
        while true {
            var urlRequestResult = await streamTask.urlRequestResult
            let adapters = [sessionAdapter, streamTask.adapter, streamTask.interceptor]
                .compactMap({ $0 })
                .sortedByPriority
            for adapter in adapters {
                urlRequestResult = await streamTask.executeAdapter(adapter, on: urlRequestResult)
            }

            let observers = sessionObservers + streamTask.observers
            let retriers = [sessionRetrier, streamTask.retrier, streamTask.interceptor]
                .compactMap({ $0 })
                .sortedByPriority

            let attempt = await self.attemptStreamConnect(streamTask: streamTask,
                                                             urlRequestResult: urlRequestResult,
                                                             observers: observers)

            switch attempt {
                case .success(let success):
                    return self.makeWrappedStream(typedStream: success.typedStream,
                                                  urlRequest: success.urlRequest,
                                                  urlResponse: success.urlResponse,
                                                  observers: success.observers,
                                                  cancelStream: success.cancelStream)
                case .failure(let failure):
                    let decision = await streamTask.consultRetriers(error: failure.error,
                                                                       urlRequest: failure.urlRequest,
                                                                       urlResponse: failure.urlResponse,
                                                                       retriers: retriers)
                    if try await handleStreamRetryDecision(decision) { continue }
                    throw failure.error
            }
        }
    }
}

/// Carries the result of a successful streaming connect attempt: the typed chunk stream the
/// caller will return, plus the context needed to fire `willBeginStream` /
/// `didFinishStream` against the right observers. `urlRequest` is `nil` for the mock
/// path; in that case `observers` is empty so no notifications fire (matches response
/// `mockSerializedResult` semantics).
///
/// `cancelStream` is the byte source's cleanup hook (e.g. `URLSessionDataTask.cancel()` for
/// the real `URLSession`, no-op for mocks). The wrapper calls it from `onTermination` so
/// consumer-side iteration ending tears down the network resources promptly.
@available(iOS 15, macOS 12, tvOS 15, watchOS 8, visionOS 1, *)
internal struct StreamConnectSuccess<Chunk: Sendable>: Sendable {
    let typedStream: AsyncThrowingStream<Chunk, Error>
    let urlRequest: URLRequest?
    let urlResponse: URLResponse
    let observers: [NetworkingTransportObserver]
    let cancelStream: @Sendable () -> Void
}

/// Carries the result of a failed streaming connect attempt. `urlRequest` may be `nil` if
/// the failure was URLRequest building (or the mock path); `urlResponse` may be `nil` if
/// the failure was before the response head arrived (transport error).
internal struct StreamConnectFailure: Error, Sendable {
    let error: Error
    let urlRequest: URLRequest?
    let urlResponse: URLResponse?
}

@available(iOS 15, macOS 12, tvOS 15, watchOS 8, visionOS 1, *)
private extension NetworkingSession {

    /// Performs one streaming connect attempt and funnels its outcome into a `Result`. All
    /// observer events that should fire during this attempt (`willSend`, `didFail`) are
    /// fired inside this method on the correct paths — observer events that depend on
    /// success (`willBeginStream`) happen via the wrapped stream the caller returns.
    func attemptStreamConnect<ResponseRoute: NetworkingStreamRoute>(streamTask: StreamRouteTask<ResponseRoute>,
                                                                  urlRequestResult: Result<URLRequest, Error>,
                                                                  observers: [NetworkingTransportObserver]) async -> Result<StreamConnectSuccess<ResponseRoute.Serializer.Chunk>, StreamConnectFailure> {

        // Mock path. Adapters have already run; `bytes(for:)` and observer notifications
        // are skipped (matches response `mockSerializedResult` semantics). The serializer
        // still runs — a synchronous throw here funnels into the unified retry path.
        if !streamTask.mockChunks.isEmpty {
            let mockedByteStream = makeMockedByteStream(chunks: streamTask.mockChunks)
            let mockUrlResponse = URLResponse()
            do {
                let typedStream = try await streamTask.serializer.stream(byteStream: mockedByteStream,
                                                                                     urlResponse: mockUrlResponse)
                return .success(StreamConnectSuccess(typedStream: typedStream,
                                                        urlRequest: nil,
                                                        urlResponse: mockUrlResponse,
                                                        observers: [],
                                                        cancelStream: { }))
            } catch {
                return .failure(StreamConnectFailure(error: error, urlRequest: nil, urlResponse: mockUrlResponse))
            }
        }

        // Real path: extract URLRequest or fail early.
        let urlRequest: URLRequest
        switch urlRequestResult {
            case .failure(let error):
                return .failure(StreamConnectFailure(error: error, urlRequest: nil, urlResponse: nil))
            case .success(let req):
                urlRequest = req
        }

        await observers.notifyConcurrently { await $0.willSend(urlRequest: urlRequest) }

        let byteStream: AsyncThrowingStream<Data, Error>
        let urlResponse: URLResponse
        let cancelStream: @Sendable () -> Void
        do {
            (byteStream, urlResponse, cancelStream) = try await self._urlSession.bytes(for: urlRequest,
                                                                                       byteChunkSize: streamTask.byteChunkSize)
        } catch {
            await observers.notifyConcurrently { await $0.didFail(urlRequest: urlRequest, dueTo: error) }
            return .failure(StreamConnectFailure(error: error, urlRequest: urlRequest, urlResponse: nil))
        }

        let typedStream: AsyncThrowingStream<ResponseRoute.Serializer.Chunk, Error>
        do {
            typedStream = try await streamTask.serializer.stream(byteStream: byteStream,
                                                                             urlResponse: urlResponse)
        } catch {
            await observers.notifyConcurrently { await $0.didFail(urlRequest: urlRequest, dueTo: error) }
            // Connect failed at serializer-validation stage. Tear down the live byte source
            // before retrying — otherwise the URLSessionDataTask leaks.
            cancelStream()
            return .failure(StreamConnectFailure(error: error, urlRequest: urlRequest, urlResponse: urlResponse))
        }

        // Connect succeeded. Fire willBeginStream before the wrapped stream is returned.
        await observers.notifyConcurrently {
            await $0.willBeginStream(urlRequest: urlRequest, urlResponse: urlResponse)
        }

        return .success(StreamConnectSuccess(typedStream: typedStream,
                                                urlRequest: urlRequest,
                                                urlResponse: urlResponse,
                                                observers: observers,
                                                cancelStream: cancelStream))
    }

    /// Acts on a retry decision from a connect-time failure. Returns `true` if the caller
    /// should `continue` the connect-attempt loop, `false` if it should `throw` the original
    /// error. `.retryWithDelay` sleeps before returning `true`; sleep-cancellation rethrows
    /// as `URLError(.cancelled)`.
    func handleStreamRetryDecision(_ decision: NetworkingRetrierResult) async throws -> Bool {
        switch decision {
            case .doNotRetry:
                return false
            case .retry:
                return true
            case .retryWithDelay(let delay):
                do {
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    return true
                } catch {
                    throw URLError(.cancelled)
                }
        }
    }

    /// Synthesizes a byte stream from the route's `mockChunks`. Each successful chunk is
    /// yielded in order; a `.failure` terminates the synthesized stream with that error
    /// mid-flight (used to simulate transport-style errors arriving partway through).
    func makeMockedByteStream(chunks: [Result<Data, Error>]) -> AsyncThrowingStream<Data, Error> {
        AsyncThrowingStream<Data, Error>(bufferingPolicy: .unbounded) { continuation in
            let task = Task {
                for chunk in chunks {
                    if Task.isCancelled { break }
                    switch chunk {
                        case .success(let data):
                            continuation.yield(data)
                        case .failure(let error):
                            continuation.finish(throwing: error)
                            return
                    }
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// Wraps the serializer's typed chunk stream into the stream the consumer iterates.
    ///
    /// Responsibilities of this layer:
    /// * Fires `didFinishStream` once iteration ends (clean EOF, mid-stream error, or
    ///   consumer cancellation).
    /// * On `onTermination`, cancels the inner Task AND invokes `cancelStream` — the latter
    ///   tears down the underlying byte source (e.g. `URLSessionDataTask.cancel()`).
    ///   Calling `cancelStream` here is what makes consumer-initiated cancellation actually
    ///   release network resources; relying on `AsyncThrowingStream` iterator-deinit
    ///   propagation through multiple wrapping layers is unreliable.
    ///
    /// `urlRequest == nil` indicates the mock-chunks path; in that case `observers` is empty,
    /// matching the response `mockSerializedResult` semantics of skipping observer events.
    /// `cancelStream` for the mock path is a no-op closure.
    func makeWrappedStream<Chunk: Sendable>(typedStream: AsyncThrowingStream<Chunk, Error>,
                                            urlRequest: URLRequest?,
                                            urlResponse: URLResponse,
                                            observers: [NetworkingTransportObserver],
                                            cancelStream: @escaping @Sendable () -> Void) -> AsyncThrowingStream<Chunk, Error> {
        AsyncThrowingStream<Chunk, Error>(bufferingPolicy: .unbounded) { continuation in
            let task = Task {
                var capturedError: Error? = nil
                do {
                    for try await chunk in typedStream {
                        try Task.checkCancellation()
                        continuation.yield(chunk)
                    }
                } catch {
                    capturedError = error
                }
                let streamError = capturedError
                if let request = urlRequest {
                    await observers.notifyConcurrently {
                        await $0.didFinishStream(urlRequest: request, urlResponse: urlResponse, error: streamError)
                    }
                }
                continuation.finish(throwing: streamError)
            }
            continuation.onTermination = { _ in
                task.cancel()
                cancelStream()
            }
        }
    }
}
