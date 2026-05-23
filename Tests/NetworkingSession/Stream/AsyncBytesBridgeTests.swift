//
//  AsyncBytesBridgeTests.swift
//  PopNetworking
//

import XCTest
@testable import PopNetworking

@available(iOS 15, macOS 12, tvOS 15, watchOS 8, visionOS 1, *)
final class AsyncBytesBridgeTests: XCTestCase {

    // MARK: - Helpers

    /// Wraps an array of bytes as an `AsyncThrowingStream<UInt8, Error>`. Optionally throws after
    /// emitting `failingAfter` bytes — useful for verifying that an upstream failure surfaces
    /// in the bridge while preserving already-flushed chunks.
    private func byteStream(from bytes: [UInt8],
                            failingAfter index: Int? = nil,
                            error: Error? = nil) -> AsyncThrowingStream<UInt8, Error> {
        AsyncThrowingStream { continuation in
            Task {
                for (i, byte) in bytes.enumerated() {
                    if let failAt = index, i == failAt, let err = error {
                        continuation.finish(throwing: err)
                        return
                    }
                    continuation.yield(byte)
                }
                continuation.finish()
            }
        }
    }

    private func collect(_ stream: AsyncThrowingStream<Data, Error>) async throws -> [Data] {
        var collected: [Data] = []
        for try await chunk in stream {
            collected.append(chunk)
        }
        return collected
    }

    // MARK: - Single-chunk path

    func testPayloadSmallerThanChunkSizeYieldsOneChunkWithExactBytesInOrder() async throws {
        // Distinct, position-encoded payload so byte-shuffling bugs would fail the assertion.
        let payload: [UInt8] = (0..<1_000).map { UInt8($0 & 0xFF) }
        let stream = networkingDataChunkStream(
            from: byteStream(from: payload),
            chunkSize: 16 * 1024        )

        let chunks = try await collect(stream)
        XCTAssertEqual(chunks.count, 1, "Payload < chunkSize should produce exactly one chunk")
        XCTAssertEqual(Array(chunks[0]), payload, "Bridge must preserve byte values and order")
    }

    // MARK: - Multi-chunk path

    func testPayloadLargerThanChunkSizeYieldsBoundaryAlignedChunksWithBytesInOrder() async throws {
        // Position-encoded payload so reordering or byte corruption would be visible in the
        // assertion. Length = 3 full chunks + 500-byte trailing partial.
        let chunkSize = 1_024
        let payload: [UInt8] = (0..<(chunkSize * 3 + 500)).map { UInt8($0 & 0xFF) }
        let stream = networkingDataChunkStream(
            from: byteStream(from: payload),
            chunkSize: chunkSize        )

        let chunks = try await collect(stream)

        XCTAssertEqual(chunks.count, 4, "Should split into 3 full chunks + 1 partial")
        XCTAssertEqual(chunks[0].count, chunkSize)
        XCTAssertEqual(chunks[1].count, chunkSize)
        XCTAssertEqual(chunks[2].count, chunkSize)
        XCTAssertEqual(chunks[3].count, 500)

        // Concatenate and check byte-by-byte equality with the input.
        let reassembled = chunks.reduce(into: Data()) { $0.append($1) }
        XCTAssertEqual(Array(reassembled), payload,
                       "Reassembled chunks must equal the original byte sequence (in order)")
    }

    // MARK: - Empty path

    func testEmptyUpstreamFinishesWithZeroChunks() async throws {
        let stream = networkingDataChunkStream(
            from: byteStream(from: []),
            chunkSize: 1_024        )

        let chunks = try await collect(stream)
        XCTAssertTrue(chunks.isEmpty)
    }

    // MARK: - Error propagation

    func testUpstreamErrorPropagatesAfterFlushingCompletedChunksAndDropsInFlightBuffer() async throws {
        // 150-byte payload (chunkSize 100) failing at byte 125. We expect the first chunk
        // (bytes 0..<100) to be flushed, the in-flight 25 bytes (100..<125) to be DROPPED,
        // and the upstream error to surface to the consumer.
        struct UpstreamFailure: Error, Equatable {}
        let chunkSize = 100
        let payload: [UInt8] = (0..<150).map { UInt8($0) }

        let stream = networkingDataChunkStream(
            from: byteStream(from: payload, failingAfter: 125, error: UpstreamFailure()),
            chunkSize: chunkSize        )

        var chunks: [Data] = []
        var caughtError: Error?
        do {
            for try await chunk in stream {
                chunks.append(chunk)
            }
        } catch {
            caughtError = error
        }

        XCTAssertEqual(chunks.count, 1, "Only the first chunk should reach the consumer")
        XCTAssertEqual(Array(chunks[0]), Array(payload[0..<chunkSize]),
                       "First chunk must contain bytes 0..<chunkSize verbatim")
        XCTAssertEqual(caughtError as? UpstreamFailure, UpstreamFailure(),
                       "Upstream error must propagate as the same error type")
    }

    // MARK: - Cancellation

    func testConsumerBreakEndsIterationWithoutThrowing() async throws {
        // Verifies the bridge respects an early `break`: the consumer can stop iterating
        // partway through and the bridge ends cleanly (no error, no hang).
        //
        // The follow-on contract — that breaking propagates *upstream* cancellation to the
        // source's underlying resource — is not unit-testable here. With `.unbounded`
        // buffering, source's `next()` returns response values synchronously and the bridge
        // Task's `withTaskCancellationHandler` inside `next()` rarely fires. Source's
        // continuation also stays captured by its producer Task, so iterator-deinit alone
        // doesn't fire `onTermination` for a generic AsyncThrowingStream source.
        //
        // For our actual production source — `URLSession.AsyncBytes` — Apple's implementation
        // overrides iterator deinit to cancel the underlying `URLSessionDataTask`, so
        // cancellation propagates correctly. That path is covered by integration tests that
        // run against a real URLSession, not by these isolated bridge unit tests.
        let payload: [UInt8] = (0..<1_000).map { UInt8($0 & 0xFF) }
        let stream = networkingDataChunkStream(
            from: byteStream(from: payload),
            chunkSize: 100        )

        var chunkCount = 0
        for try await _ in stream {
            chunkCount += 1
            if chunkCount == 2 { break }
        }

        XCTAssertEqual(chunkCount, 2,
                       "Consumer should be able to break after exactly two chunks without the bridge throwing or producing more chunks downstream")
    }
}
