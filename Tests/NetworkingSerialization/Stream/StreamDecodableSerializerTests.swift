//
//  StreamDecodableSerializerTests.swift
//  PopNetworking
//

import XCTest
@testable import PopNetworking

@available(iOS 15, macOS 12, tvOS 15, watchOS 8, visionOS 1, *)
final class StreamDecodableSerializerTests: XCTestCase {

    private struct LogEntry: Decodable, Equatable, Sendable {
        let id: Int
        let message: String
    }

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

    func testDecodesOneEntryPerLine() async throws {
        let payload = """
        {"id":1,"message":"first"}
        {"id":2,"message":"second"}
        {"id":3,"message":"third"}

        """
        let serializer = NetworkingSerializers.Stream.Decodable<LogEntry>()
        let stream = try await serializer.stream(byteStream: byteStream(yielding: [payload]),
                                                 urlResponse: URLResponse())
        let entries = try await collect(stream)
        XCTAssertEqual(entries, [
            LogEntry(id: 1, message: "first"),
            LogEntry(id: 2, message: "second"),
            LogEntry(id: 3, message: "third"),
        ])
    }

    func testJSONSpanningMultipleChunks_isReassembled() async throws {
        // The JSON object for entry 1 is split across chunk boundaries.
        let chunks = [
            #"{"id":1,"#,
            #""message":"first"}"# + "\n",
            #"{"id":2,"message":"second"}"# + "\n",
        ]
        let serializer = NetworkingSerializers.Stream.Decodable<LogEntry>()
        let stream = try await serializer.stream(byteStream: byteStream(yielding: chunks),
                                                 urlResponse: URLResponse())
        let entries = try await collect(stream)
        XCTAssertEqual(entries, [
            LogEntry(id: 1, message: "first"),
            LogEntry(id: 2, message: "second"),
        ])
    }

    func testEmptyLinesAreSkipped() async throws {
        let payload = """
        {"id":1,"message":"a"}


        {"id":2,"message":"b"}

        """
        let serializer = NetworkingSerializers.Stream.Decodable<LogEntry>()
        let stream = try await serializer.stream(byteStream: byteStream(yielding: [payload]),
                                                 urlResponse: URLResponse())
        let entries = try await collect(stream)
        XCTAssertEqual(entries, [
            LogEntry(id: 1, message: "a"),
            LogEntry(id: 2, message: "b"),
        ])
    }

    func testMalformedLine_propagatesDecodeError_afterValidEntries() async throws {
        let payload = """
        {"id":1,"message":"valid"}
        not-json-{garbage}
        {"id":2,"message":"never-reached"}

        """
        let serializer = NetworkingSerializers.Stream.Decodable<LogEntry>()
        let stream = try await serializer.stream(byteStream: byteStream(yielding: [payload]),
                                                 urlResponse: URLResponse())

        var collected: [LogEntry] = []
        var caughtError: Error?
        do {
            for try await entry in stream {
                collected.append(entry)
            }
        } catch {
            caughtError = error
        }

        XCTAssertEqual(collected, [LogEntry(id: 1, message: "valid")],
                       "Valid entries before the malformed line must reach the consumer")
        XCTAssertNotNil(caughtError, "Malformed JSON must surface a DecodingError to the consumer")
        XCTAssertTrue(caughtError is DecodingError,
                      "Expected DecodingError, got \(String(describing: caughtError))")
    }

    func testTrailingPartialLineWithoutNewline_isDecodedAtEOF() async throws {
        // Last line has no trailing newline.
        let payload = #"{"id":1,"message":"a"}"# + "\n" + #"{"id":2,"message":"b"}"#
        let serializer = NetworkingSerializers.Stream.Decodable<LogEntry>()
        let stream = try await serializer.stream(byteStream: byteStream(yielding: [payload]),
                                                 urlResponse: URLResponse())
        let entries = try await collect(stream)
        XCTAssertEqual(entries, [
            LogEntry(id: 1, message: "a"),
            LogEntry(id: 2, message: "b"),
        ])
    }

    func testCRLFLineEndings_areNormalized() async throws {
        // Some servers emit CRLF-terminated NDJSON. The trailing CR must not appear in the
        // bytes passed to the decoder (which would fail JSON parsing).
        let payload = #"{"id":1,"message":"a"}"# + "\r\n"
                    + #"{"id":2,"message":"b"}"# + "\r\n"
        let serializer = NetworkingSerializers.Stream.Decodable<LogEntry>()
        let stream = try await serializer.stream(byteStream: byteStream(yielding: [payload]),
                                                 urlResponse: URLResponse())
        let entries = try await collect(stream)
        XCTAssertEqual(entries, [
            LogEntry(id: 1, message: "a"),
            LogEntry(id: 2, message: "b"),
        ], "CRLF endings should yield the same decoded entries as LF endings")
    }

    func testCustomJSONDecoder_isUsedForDecoding() async throws {
        // Inject a decoder with `.convertFromSnakeCase` and feed snake_case JSON. If the
        // serializer ignores the supplied decoder and constructs its own, the test fails
        // (the camelCase property won't decode from snake_case JSON).
        struct SnakeEntry: Decodable, Equatable, Sendable {
            let entryId: Int
            let userMessage: String
        }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        let payload = #"{"entry_id":1,"user_message":"hi"}"# + "\n"
        let serializer = NetworkingSerializers.Stream.Decodable<SnakeEntry>(decoder: decoder)
        let stream = try await serializer.stream(byteStream: byteStream(yielding: [payload]),
                                                 urlResponse: URLResponse())
        let entries = try await collect(stream)
        XCTAssertEqual(entries, [SnakeEntry(entryId: 1, userMessage: "hi")],
                       "The injected JSONDecoder's keyDecodingStrategy must be honored")
    }
}
