//
//  StreamRouteTaskTests.swift
//

import XCTest
@testable import PopNetworking

@available(iOS 15, macOS 12, tvOS 15, watchOS 8, visionOS 1, *)
final class StreamRouteTaskTests: XCTestCase {

    private actor Collected<T: Sendable> {
        private(set) var items: [T] = []
        func append(_ item: T) { self.items.append(item) }
    }

    private struct MidStreamFailure: Error, Equatable {}
    private struct ConnectFailure: Error, Equatable {}

    func test_task_yieldsChunksInOrderAndCompletesCleanly() async throws {
        let collected = Collected<Data>()
        let route = Mock.StreamRoute(
            session: NetworkingSession(urlSession: Mock.UrlSession()),
            serializer: Mock.Stream.dataPassthroughSerializer(),
            mockChunks: [.success(Data([0x01])), .success(Data([0x02])), .success(Data([0x03]))]
        )

        let handle = route.task { chunk in
            await collected.append(chunk)
        }

        try await handle.value
        let items = await collected.items
        XCTAssertEqual(items, [Data([0x01]), Data([0x02]), Data([0x03])])
    }

    func test_task_throwsOnMidStreamFailure() async throws {
        let collected = Collected<Data>()
        // Serializer yields its own chunks then throws — input byte stream is
        // ignored, so the route's `mockChunks` is irrelevant here.
        let serializerChunks = [Data([0xA1]), Data([0xA2])]
        let route = Mock.StreamRoute(
            session: NetworkingSession(urlSession: Mock.UrlSession()),
            serializer: Mock.Stream.Serializer<Data>.yieldThenError(
                serializerChunks,
                error: MidStreamFailure()
            )
        )

        let handle = route.task { chunk in
            await collected.append(chunk)
        }

        do {
            try await handle.value
            XCTFail("Expected task to throw on mid-stream failure")
        } catch let error as MidStreamFailure {
            XCTAssertEqual(error, MidStreamFailure())
        } catch {
            XCTFail("Wrong error type: \(error)")
        }

        let items = await collected.items
        XCTAssertEqual(items, serializerChunks, "Chunks before the failure should still be delivered")
    }

    func test_task_throwsOnConnectFailure() async throws {
        let route = Mock.StreamRoute(
            session: NetworkingSession(urlSession: Mock.UrlSession()),
            serializer: Mock.Stream.Serializer<Data>.throwImmediately(ConnectFailure())
        )

        let handle = route.task { _ in
            XCTFail("onChunk should not fire when connect fails")
        }

        do {
            try await handle.value
            XCTFail("Expected task to throw on connect failure")
        } catch let error as ConnectFailure {
            XCTAssertEqual(error, ConnectFailure())
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }

    func test_task_cancellation_stopsChunkDelivery() async throws {
        let totalChunks = 20
        let chunksProcessed = Collected<Data>()
        let mockChunks: [Result<Data, Error>] = (0..<totalChunks).map { _ in .success(Data([0x01])) }
        let route = Mock.StreamRoute(
            session: NetworkingSession(urlSession: Mock.UrlSession()),
            serializer: Mock.Stream.dataPassthroughSerializer(),
            mockChunks: mockChunks
        )

        // Each chunk handler takes 50ms — 1 second to process all 20 naturally.
        let handle = route.task { chunk in
            await chunksProcessed.append(chunk)
            try? await Task.sleep(nanoseconds: 50_000_000)
        }

        // Let at least one chunk start processing, then cancel.
        try? await Task.sleep(nanoseconds: 20_000_000)
        handle.cancel()

        // Drain to completion (whether by throw or clean exit — both are acceptable
        // outcomes for cancellation; the real assertion is on chunk count).
        _ = try? await handle.value

        let count = await chunksProcessed.items.count
        XCTAssertLessThan(count, totalChunks,
                          "Cancellation should stop chunk delivery before all \(totalChunks) chunks are processed (got \(count))")
        XCTAssertGreaterThan(count, 0,
                             "At least one chunk should have been processed before cancellation hit")
    }
}
