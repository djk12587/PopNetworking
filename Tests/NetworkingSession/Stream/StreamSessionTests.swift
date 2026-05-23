//
//  StreamSessionTests.swift
//  PopNetworking
//

import XCTest
@testable import PopNetworking

@available(iOS 15, macOS 12, tvOS 15, watchOS 8, visionOS 1, *)
final class StreamSessionTests: XCTestCase {

    // MARK: - Helpers

    private func collect<Chunk>(_ stream: AsyncThrowingStream<Chunk, Error>) async throws -> [Chunk] {
        var chunks: [Chunk] = []
        for try await chunk in stream {
            chunks.append(chunk)
        }
        return chunks
    }

    // MARK: - Happy path

    func testHappyPath_yieldsAllChunks_andFiresObserverEventsInOrderWithCorrectContext() async throws {
        let observer = Mock.Observer()
        let mockResponse = HTTPURLResponse(url: URL(string: "https://mockUrl.com/")!,
                                           statusCode: 200,
                                           httpVersion: "HTTP/1.1",
                                           headerFields: nil)!
        let urlSession = Mock.UrlSession(
            mockResult: .success(Data("ignored".utf8)),
            mockUrlResponse: mockResponse,
            mockBytesChunks: [.success(Data([0x01])), .success(Data([0x02])), .success(Data([0x03]))]
        )
        let session = NetworkingSession(urlSession: urlSession, observers: [observer])
        let route = Mock.StreamRoute(
            baseUrl: "https://mockUrl.com",
            path: "stream-endpoint",
            session: session,
            serializer: Mock.Stream.dataPassthroughSerializer()
        )

        let stream = try await route.stream
        let chunks = try await collect(stream)

        XCTAssertEqual(chunks.map(Array.init), [[0x01], [0x02], [0x03]],
                       "All mock chunks should reach the consumer in order")

        // Observer events fire BEFORE the consumer's loop exits (see makeWrappedStream
        // implementation note), so all observer state is settled by the time we get here.
        let log = await observer.eventLog
        XCTAssertEqual(log, ["willSend", "willBeginStream", "didFinishStream"],
                       "Observer events should fire in lifecycle order")

        // Verify the observer received the actual request and response, not just placeholder events.
        let capturedRequest = await observer.capturedWillSendUrlRequest
        XCTAssertEqual(capturedRequest?.url?.absoluteString, "https://mockUrl.com/stream-endpoint",
                       "willSend should receive the route's actual URLRequest")
        let capturedBeginResponse = await observer.capturedWillBeginStreamUrlResponse as? HTTPURLResponse
        XCTAssertEqual(capturedBeginResponse?.statusCode, 200,
                       "willBeginStream should receive the actual HTTPURLResponse")
        let finishError = await observer.capturedDidFinishStreamError
        XCTAssertNil(finishError, "Clean EOF should fire didFinishStream with nil error")

        let willSendCount = await observer.willSendCallCount
        let willBeginCount = await observer.willBeginStreamCallCount
        let didFinishCount = await observer.didFinishStreamCallCount
        XCTAssertEqual(willSendCount, 1, "willSend should fire exactly once on the happy path")
        XCTAssertEqual(willBeginCount, 1, "willBeginStream should fire exactly once")
        XCTAssertEqual(didFinishCount, 1, "didFinishStream should fire exactly once")
    }

    // MARK: - Connect-time retry

    func testTransportFailure_consultsRetrierOnce_thenSucceedsOnRetry() async throws {
        let transportError = URLError(.notConnectedToInternet)
        let urlSessions = Mock.UrlSessions(
            mockResults: [
                .failure(transportError),                           // attempt 1: transport fails
                .success(Data())                                    // attempt 2: succeeds
            ],
            mockBytesChunksByAttempt: [
                [],                                                 // attempt 1 has nothing to yield
                [.success(Data([0xFE]))]                            // attempt 2 yields one chunk
            ]
        )
        let retrier = Mock.Interceptor(adapterResult: .doNotAdapt, retrierResult: .retry)
        let session = NetworkingSession(urlSession: urlSessions, retrier: retrier)
        let route = Mock.StreamRoute(
            session: session,
            serializer: Mock.Stream.dataPassthroughSerializer()
        )

        let stream = try await route.stream
        let chunks = try await collect(stream)

        XCTAssertEqual(chunks.map(Array.init), [[0xFE]],
                       "After retry, the second attempt's chunk should reach the consumer")

        let retryCount = await retrier.retryCounter
        XCTAssertEqual(retryCount, 1, "Retrier should be consulted exactly once (on the single transport failure)")
        let retrierPayload = await retrier.retrierPayload
        XCTAssertEqual((retrierPayload?.error as? URLError)?.code, transportError.code,
                       "Retrier should receive the transport error that caused the failure")
    }

    func testSerializerThrowOnBadResponse_consultsRetrierOnce() async throws {
        struct BadStatus: Error, Equatable {}
        let urlSession = Mock.UrlSession(
            mockResult: .success(Data()),
            mockBytesChunks: [.success(Data([0x01]))]
        )
        let retrier = Mock.Interceptor(adapterResult: .doNotAdapt, retrierResult: .doNotRetry)
        let session = NetworkingSession(urlSession: urlSession, retrier: retrier)
        let route = Mock.StreamRoute(
            session: session,
            serializer: Mock.Stream.Serializer<Data>.throwImmediately(BadStatus())
        )

        do {
            _ = try await route.stream
            XCTFail("Expected serializer-throw to propagate after retrier said doNotRetry")
        } catch is BadStatus {
            // expected
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }

        let retryCount = await retrier.retryCounter
        XCTAssertEqual(retryCount, 1, "Retrier should be consulted exactly once on the serializer throw")
        let retrierPayload = await retrier.retrierPayload
        XCTAssertTrue(retrierPayload?.error is BadStatus,
                      "Retrier should receive the serializer's thrown error")
    }

    // MARK: - Mid-stream behavior (no retry)

    func testMidStreamError_propagatesToConsumer_doesNotConsultRetrier() async throws {
        struct MidStreamFailure: Error, Equatable {}
        let urlSession = Mock.UrlSession(
            mockResult: .success(Data()),
            mockBytesChunks: [.success(Data([0xAA]))]
        )
        let retrier = Mock.Interceptor(adapterResult: .doNotAdapt, retrierResult: .retry)
        let observer = Mock.Observer()
        let session = NetworkingSession(urlSession: urlSession, retrier: retrier, observers: [observer])
        let route = Mock.StreamRoute(
            session: session,
            serializer: Mock.Stream.Serializer<Data>.yieldThenError([Data([0xAA])], error: MidStreamFailure())
        )

        let stream = try await route.stream
        var chunks: [Data] = []
        var caughtError: Error?
        do {
            for try await chunk in stream {
                chunks.append(chunk)
            }
        } catch {
            caughtError = error
        }

        XCTAssertEqual(chunks.map(Array.init), [[0xAA]], "Chunks yielded before the error should reach the consumer")
        XCTAssertTrue(caughtError is MidStreamFailure, "Mid-stream error should propagate to the consumer")

        let retryCount = await retrier.retryCounter
        XCTAssertEqual(retryCount, 0, "Retrier must NOT be consulted on mid-stream errors")

        let finishError = await observer.capturedDidFinishStreamError
        XCTAssertTrue(finishError is MidStreamFailure, "didFinishStream should fire with the mid-stream error")
        let didFinishCount = await observer.didFinishStreamCallCount
        XCTAssertEqual(didFinishCount, 1, "didFinishStream should fire exactly once")
    }

    // MARK: - Mock chunks path

    func testMockChunks_success_skipsNetworkAndObservers_yieldsThroughSerializer() async throws {
        let observer = Mock.Observer()
        let urlSession = Mock.UrlSession()
        let session = NetworkingSession(urlSession: urlSession, observers: [observer])
        let route = Mock.StreamRoute(
            session: session,
            serializer: Mock.Stream.dataPassthroughSerializer(),
            mockChunks: [.success(Data([0x10])), .success(Data([0x20]))]
        )

        let stream = try await route.stream
        let chunks = try await collect(stream)

        XCTAssertEqual(chunks.map(Array.init), [[0x10], [0x20]],
                       "Mock chunks should flow through the serializer to the consumer")

        let lastRequest = await urlSession.lastRequest
        XCTAssertNil(lastRequest,
                     "Mock path must skip the network — Mock.UrlSession's bytes(for:) / data(for:) should never be invoked")

        let log = await observer.eventLog
        XCTAssertTrue(log.isEmpty,
                      "Mock path must skip all observer notifications (got: \(log))")
    }

    func testMockChunks_serializerThrows_consultsRetrierOnce() async throws {
        struct MockSerializerRejection: Error, Equatable {}
        let retrier = Mock.Interceptor(adapterResult: .doNotAdapt, retrierResult: .doNotRetry)
        let urlSession = Mock.UrlSession()
        let session = NetworkingSession(urlSession: urlSession, retrier: retrier)
        let route = Mock.StreamRoute(
            session: session,
            serializer: Mock.Stream.Serializer<Data>.throwImmediately(MockSerializerRejection()),
            mockChunks: [.success(Data([0x01]))]
        )

        do {
            _ = try await route.stream
            XCTFail("Expected serializer-throw on mock path to propagate after doNotRetry")
        } catch is MockSerializerRejection {
            // expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        let lastRequest = await urlSession.lastRequest
        XCTAssertNil(lastRequest, "Mock path must skip the network even when the serializer throws")

        let retryCount = await retrier.retryCounter
        XCTAssertEqual(retryCount, 1, "Retrier should be consulted exactly once on mock-path serializer throw")
    }

    // MARK: - Observer composition

    func testSessionAndRouteObservers_bothFireAllLifecycleEvents() async throws {
        let sessionObserver = Mock.Observer()
        let routeObserver = Mock.Observer()
        let urlSession = Mock.UrlSession(
            mockResult: .success(Data()),
            mockBytesChunks: [.success(Data([0x42]))]
        )
        let session = NetworkingSession(urlSession: urlSession, observers: [sessionObserver])
        let route = Mock.StreamRoute(
            session: session,
            serializer: Mock.Stream.dataPassthroughSerializer(),
            observers: [routeObserver]
        )

        let stream = try await route.stream
        _ = try await collect(stream)

        let sessionLog = await sessionObserver.eventLog
        let routeLog = await routeObserver.eventLog
        XCTAssertEqual(sessionLog, ["willSend", "willBeginStream", "didFinishStream"],
                       "Session-level observer should fire all lifecycle events")
        XCTAssertEqual(routeLog, ["willSend", "willBeginStream", "didFinishStream"],
                       "ResponseRoute-level observer should fire all lifecycle events")
    }
}
