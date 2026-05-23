//
//  AsyncBytes+Bridge.swift
//  PopNetworking
//

import Foundation

/// Default chunk size used when batching a byte-level `AsyncSequence` into `Data` chunks.
///
/// 16 KB matches typical OS page / network MTU multiples and is what `URLSession` already
/// buffers internally. Routes can override via ``NetworkingStreamRoute/byteChunkSize`` —
/// smaller values reduce latency for slowly-emitting streams (e.g. LLM token output) at the
/// cost of more per-chunk overhead; larger values amortize that overhead at the cost of
/// holding more bytes before the consumer sees them.
public let networkingDefaultByteChunkSize = 16 * 1024

/// Bridges a byte-level `AsyncSequence` (e.g. `URLSession.AsyncBytes`) into a `Data`-chunk
/// stream. Bytes are accumulated into a buffer of `chunkSize` bytes and flushed when the
/// buffer fills or the upstream finishes. The trailing partial buffer is flushed at EOF.
///
/// The bridge stream is `.unbounded` — bounded buffering would drop chunks and corrupt
/// response parsing for the framework's serializers (SSE, NDJSON, etc.). Consumers that
/// want to drop chunks can do so inside their own `for-await` loop.
///
/// Cancellation: when the returned stream's continuation terminates, the inner `Task` is
/// cancelled, which ends iteration of the upstream sequence. **The underlying transport
/// (e.g. `URLSessionDataTask`) is not cancelled by this bridge** — that's the session's
/// responsibility via the cancel closure returned from
/// ``URLSessionProtocol/bytes(for:byteChunkSize:)``.
@available(iOS 15, macOS 12, tvOS 15, watchOS 8, visionOS 1, *)
internal func networkingDataChunkStream<Source: AsyncSequence & Sendable>(
    from source: Source,
    chunkSize: Int
) -> AsyncThrowingStream<Data, Error> where Source.Element == UInt8 {
    AsyncThrowingStream<Data, Error>(bufferingPolicy: .unbounded) { continuation in
        let task = Task {
            var buffer = Data()
            buffer.reserveCapacity(chunkSize)
            do {
                for try await byte in source {
                    try Task.checkCancellation()
                    buffer.append(byte)
                    if buffer.count >= chunkSize {
                        continuation.yield(buffer)
                        buffer.removeAll(keepingCapacity: true)
                    }
                }
                if !buffer.isEmpty {
                    continuation.yield(buffer)
                }
                continuation.finish()
            } catch {
                continuation.finish(throwing: error)
            }
        }
        continuation.onTermination = { _ in
            task.cancel()
        }
    }
}
