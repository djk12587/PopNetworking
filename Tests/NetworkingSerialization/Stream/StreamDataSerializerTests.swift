//
//  StreamDataSerializerTests.swift
//  PopNetworking
//

import XCTest
@testable import PopNetworking

@available(iOS 15, macOS 12, tvOS 15, watchOS 8, visionOS 1, *)
final class StreamDataSerializerTests: XCTestCase {

    private func byteStream(yielding chunks: [Data]) -> AsyncThrowingStream<Data, Error> {
        AsyncThrowingStream { continuation in
            Task {
                for chunk in chunks { continuation.yield(chunk) }
                continuation.finish()
            }
        }
    }

    private func collect<C>(_ stream: AsyncThrowingStream<C, Error>) async throws -> [C] {
        var out: [C] = []
        for try await chunk in stream { out.append(chunk) }
        return out
    }

    func testYieldsEachUpstreamChunkVerbatimInOrder() async throws {
        let payload: [Data] = [
            Data("hello".utf8),
            Data(" world".utf8),
            Data("!".utf8)
        ]
        let serializer = NetworkingSerializers.Stream.Data()
        let stream = try await serializer.stream(byteStream: byteStream(yielding: payload),
                                                 urlResponse: URLResponse())

        let chunks = try await collect(stream)
        XCTAssertEqual(chunks, payload, "Each upstream Data chunk must be forwarded verbatim and in order")
    }

    func testEmptyUpstreamYieldsZeroChunks() async throws {
        let serializer = NetworkingSerializers.Stream.Data()
        let stream = try await serializer.stream(byteStream: byteStream(yielding: []),
                                                 urlResponse: URLResponse())
        let chunks = try await collect(stream)
        XCTAssertTrue(chunks.isEmpty)
    }
}
