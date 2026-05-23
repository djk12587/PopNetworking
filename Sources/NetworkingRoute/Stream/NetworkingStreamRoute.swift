//
//  NetworkingStreamRoute.swift
//  PopNetworking
//

import Foundation

/// ``NetworkingStreamRoute`` describes a streaming HTTP route: how to build the request
/// (via ``NetworkingEndpoint``), what hooks attach to it (via ``NetworkingHooks``), and how
/// to parse the incoming byte stream into typed chunks delivered incrementally to the consumer.
///
/// Streaming routes are the right shape for endpoints that emit data over time — Server-Sent
/// Events, NDJSON log feeds, large file downloads with progress, LLM token streams.
///
/// ## Lifecycle
///
/// 1. Adapters mutate the `URLRequest`.
/// 2. The session calls ``URLSessionProtocol/bytes(for:byteChunkSize:)``.
/// 3. The serializer's ``NetworkingStreamSerializer/stream(byteStream:urlResponse:)``
///    runs at connect time — it either throws to reject the response (status-based retry
///    fires) or returns a typed chunk stream.
/// 4. The session returns the chunk stream to the caller. From this point, errors propagate
///    via the stream's throwing termination — they do not trigger the retrier.
///
/// ## Retry semantics
///
/// Retriers run only at *connect time* — before any chunk has been yielded to the consumer.
/// Once chunks are flowing, mid-stream errors propagate to the consumer with no retry. To
/// retry from scratch after a mid-stream failure, the consumer iterates ``stream`` again
/// (each access starts a fresh request).
///
/// ## Stopping iteration
///
/// Two natural patterns, picked by *what* tells the consumer to stop:
///
/// **In-loop condition (`break`).** Use when something observed *inside* the iteration is
/// the signal to stop:
///
/// ```swift
/// for try await event in try await chatRoute.stream {
///     handle(event)
///     if event.type == "done" { break }
/// }
/// ```
///
/// **External condition (`Task.cancel`).** Use when something *outside* the iteration
/// needs to stop it — view dismissed, parent operation aborted, timeout. Same idiom as
/// ``NetworkingResponseRoute``:
///
/// ```swift
/// let task = Task {
///     for try await event in try await chatRoute.stream { handle(event) }
/// }
/// // elsewhere:
/// task.cancel()
/// ```
///
/// Both tear down the underlying `URLSessionDataTask`. One subtlety: with `break`, the
/// transport is released when the stream itself is released — usually right after the
/// loop, but if you store the stream in long-lived state (e.g. a class property), the
/// underlying task stays alive until you release that property. For external cancellation
/// or long-lived stream storage, `Task.cancel()` is more explicit and immediate.
@available(iOS 15, macOS 12, tvOS 15, watchOS 8, visionOS 1, *)
public protocol NetworkingStreamRoute: NetworkingEndpoint, NetworkingHooks {

    /// `Serializer` parses the byte stream into typed ``NetworkingStreamSerializer/Chunk`` values. See
    /// ``NetworkingSerializers/Stream`` for prebuilt serializers.
    associatedtype Serializer: NetworkingStreamSerializer

    /// The serializer that parses incoming bytes into typed chunks. Throwing from the
    /// serializer's `stream(...)` rejects the response and triggers the connect-time retrier.
    var serializer: Serializer { get }

    /// Maximum bytes accumulated per `Data` chunk before the bridge flushes the chunk to
    /// the serializer. Defaults to ``networkingDefaultByteChunkSize`` (16 KB). Lower values
    /// reduce latency for slow streams (e.g. LLM tokens) at the cost of more per-chunk
    /// overhead; higher values amortize overhead at the cost of holding more bytes before
    /// the consumer sees them.
    var byteChunkSize: Int { get }

    /// Test seam mirroring ``NetworkingResponseRoute/mockSerializedResult``. When non-empty, the
    /// network call is skipped and the serializer receives a synthesized byte stream built
    /// from these chunks. Each entry is yielded in order; a `.failure` terminates the
    /// synthesized byte stream with that error mid-flight.
    ///
    /// Adapters, retriers, and interceptors still run; ``URLSessionProtocol/bytes(for:byteChunkSize:)``
    /// and ``NetworkingTransportObserver`` notifications do not.
    var mockChunks: [Result<Data, Error>] { get }
}

@available(iOS 15, macOS 12, tvOS 15, watchOS 8, visionOS 1, *)
public extension NetworkingStreamRoute {

    var byteChunkSize: Int { networkingDefaultByteChunkSize }
    var mockChunks: [Result<Data, Error>] { [] }

    /// Executes the route and returns the typed chunk stream. Each access starts a fresh
    /// request — to "retry" a streaming route after a mid-stream failure, iterate `stream`
    /// again.
    var stream: AsyncThrowingStream<Serializer.Chunk, Error> {
        get async throws {
            try await self.session.executeStream(route: self)
        }
    }

    /// Spawns a `Task` that consumes ``stream``, calling `onChunk` once per chunk in
    /// arrival order. Returns a `Task<Void, Error>` you can store, cancel, or `await` to
    /// observe completion.
    ///
    /// - The returned task completes normally on clean EOF.
    /// - It throws if the stream fails (transport error, serializer rejection,
    ///   mid-stream failure) or the consumer cancels it (`URLError(.cancelled)`).
    /// - Cancelling the returned task tears down the entire chain (consumer loop →
    ///   typed stream → byte stream → `URLSessionDataTask`).
    ///
    /// ```swift
    /// let handle = chatRoute.task { event in
    ///     await store.append(event.data)
    /// }
    ///
    /// // Optional: observe completion
    /// Task {
    ///     do { try await handle.value }
    ///     catch { log("stream failed: \(error)") }
    /// }
    ///
    /// // Cancel from anywhere
    /// handle.cancel()
    /// ```
    ///
    /// - Parameters:
    ///   - priority: Optional `TaskPriority` for the spawned task.
    ///   - onChunk: Called once per chunk, sequentially. Awaiting inside this closure
    ///     back-pressures the upstream — no further chunks are pulled while it runs.
    /// - Returns: A `Task<Void, Error>` that throws on stream failure.
    @discardableResult
    func task(priority: TaskPriority? = nil,
              onChunk: @Sendable @escaping (Serializer.Chunk) async -> Void) -> Task<Void, Error> {
        Task(priority: priority) {
            for try await chunk in try await self.stream {
                try Task.checkCancellation()
                await onChunk(chunk)
            }
        }
    }
}
