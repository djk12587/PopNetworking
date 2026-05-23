//
//  StreamLineSerializerTests.swift
//  PopNetworking
//

import XCTest
@testable import PopNetworking

@available(iOS 15, macOS 12, tvOS 15, watchOS 8, visionOS 1, *)
final class StreamLineSerializerTests: XCTestCase {

    private func byteStream(yielding chunks: [String]) -> AsyncThrowingStream<Data, Error> {
        AsyncThrowingStream { continuation in
            Task {
                for s in chunks { continuation.yield(Data(s.utf8)) }
                continuation.finish()
            }
        }
    }

    private func collect<C>(_ stream: AsyncThrowingStream<C, Error>) async throws -> [C] {
        var out: [C] = []
        for try await chunk in stream { out.append(chunk) }
        return out
    }

    func testSplitsOnLF_oneChunkPerLine() async throws {
        let serializer = NetworkingSerializers.Stream.Line()
        let stream = try await serializer.stream(byteStream: byteStream(yielding: ["alpha\nbeta\ngamma\n"]),
                                                 urlResponse: URLResponse())
        let lines = try await collect(stream)
        XCTAssertEqual(lines, ["alpha", "beta", "gamma"])
    }

    func testNormalizesCRLF_byStrippingTrailingCR() async throws {
        let serializer = NetworkingSerializers.Stream.Line()
        let stream = try await serializer.stream(byteStream: byteStream(yielding: ["alpha\r\nbeta\r\ngamma\r\n"]),
                                                 urlResponse: URLResponse())
        let lines = try await collect(stream)
        XCTAssertEqual(lines, ["alpha", "beta", "gamma"],
                       "CRLF line endings should produce the same line content as LF endings")
    }

    func testLineSpanningMultipleChunks_isReassembled() async throws {
        let serializer = NetworkingSerializers.Stream.Line()
        // The word "world" is split across two upstream chunks. The serializer must buffer
        // bytes across chunks until it sees the line terminator.
        let stream = try await serializer.stream(byteStream: byteStream(yielding: ["hello wo", "rld\n", "second line\n"]),
                                                 urlResponse: URLResponse())
        let lines = try await collect(stream)
        XCTAssertEqual(lines, ["hello world", "second line"])
    }

    func testTrailingPartialLineWithoutNewline_isYieldedAtEOF() async throws {
        let serializer = NetworkingSerializers.Stream.Line()
        let stream = try await serializer.stream(byteStream: byteStream(yielding: ["first\nsecond"]),
                                                 urlResponse: URLResponse())
        let lines = try await collect(stream)
        XCTAssertEqual(lines, ["first", "second"],
                       "Trailing bytes without a terminating newline should be yielded as the final line")
    }

    func testEmptyLinesYieldEmptyStrings() async throws {
        let serializer = NetworkingSerializers.Stream.Line()
        let stream = try await serializer.stream(byteStream: byteStream(yielding: ["alpha\n\nbeta\n"]),
                                                 urlResponse: URLResponse())
        let lines = try await collect(stream)
        XCTAssertEqual(lines, ["alpha", "", "beta"],
                       "Consecutive newlines should produce an empty-string line in between")
    }

    func testEmptyUpstreamYieldsZeroLines() async throws {
        let serializer = NetworkingSerializers.Stream.Line()
        let stream = try await serializer.stream(byteStream: byteStream(yielding: []),
                                                 urlResponse: URLResponse())
        let lines = try await collect(stream)
        XCTAssertTrue(lines.isEmpty)
    }

    func testCRSplitAcrossChunks_isRecognizedAsCRLF_notSeparateTerminators() async throws {
        // CR at the very end of chunk 1, LF at the start of chunk 2. The serializer must
        // treat this as a single CRLF terminator, not as a bare CR plus a stray LF.
        let serializer = NetworkingSerializers.Stream.Line()
        let stream = try await serializer.stream(byteStream: byteStream(yielding: ["alpha\r", "\nbeta\n"]),
                                                 urlResponse: URLResponse())
        let lines = try await collect(stream)
        XCTAssertEqual(lines, ["alpha", "beta"],
                       "CR-end-of-chunk + LF-start-of-next-chunk must coalesce into one CRLF terminator")
    }

    func testMixedLFAndCRLF_inSameStream_areBothNormalized() async throws {
        // A real server might mix endings (rare but legal). Verify the serializer handles
        // each line independently and strips trailing CR only when present.
        let serializer = NetworkingSerializers.Stream.Line()
        let stream = try await serializer.stream(byteStream: byteStream(yielding: ["unix\nwindows\r\nback-to-unix\n"]),
                                                 urlResponse: URLResponse())
        let lines = try await collect(stream)
        XCTAssertEqual(lines, ["unix", "windows", "back-to-unix"])
    }
}
