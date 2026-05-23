//
//  StreamSSESerializerTests.swift
//  PopNetworking
//

import XCTest
@testable import PopNetworking

@available(iOS 15, macOS 12, tvOS 15, watchOS 8, visionOS 1, *)
final class StreamSSESerializerTests: XCTestCase {

    private typealias SSEEvent = NetworkingSerializers.Stream.SSEEvent

    private func byteStream(yielding chunks: [Data]) -> AsyncThrowingStream<Data, Error> {
        AsyncThrowingStream { continuation in
            Task {
                for c in chunks { continuation.yield(c) }
                continuation.finish()
            }
        }
    }

    private func byteStream(yielding strings: [String]) -> AsyncThrowingStream<Data, Error> {
        byteStream(yielding: strings.map { Data($0.utf8) })
    }

    private func collect<C>(_ stream: AsyncThrowingStream<C, Error>) async throws -> [C] {
        var out: [C] = []
        for try await chunk in stream { out.append(chunk) }
        return out
    }

    // MARK: - Single event

    func testSingleEvent_withAllFields_parsesCorrectly() async throws {
        let payload = """
        id: 42
        event: update
        data: hello world
        retry: 5000

        """
        let serializer = NetworkingSerializers.Stream.SSE()
        let stream = try await serializer.stream(byteStream: byteStream(yielding: [payload]),
                                                 urlResponse: URLResponse())
        let events = try await collect(stream)
        XCTAssertEqual(events, [
            SSEEvent(id: "42", event: "update", data: "hello world", retry: 5000)
        ])
    }

    // MARK: - Multi-line data

    func testMultipleDataLines_joinedWithLF() async throws {
        let payload = """
        data: line one
        data: line two
        data: line three

        """
        let serializer = NetworkingSerializers.Stream.SSE()
        let stream = try await serializer.stream(byteStream: byteStream(yielding: [payload]),
                                                 urlResponse: URLResponse())
        let events = try await collect(stream)
        XCTAssertEqual(events, [
            SSEEvent(id: nil, event: nil, data: "line one\nline two\nline three", retry: nil)
        ])
    }

    // MARK: - Multiple events

    func testMultipleEvents_parsedInOrder() async throws {
        let payload = """
        data: first

        data: second

        data: third

        """
        let serializer = NetworkingSerializers.Stream.SSE()
        let stream = try await serializer.stream(byteStream: byteStream(yielding: [payload]),
                                                 urlResponse: URLResponse())
        let events = try await collect(stream)
        XCTAssertEqual(events, [
            SSEEvent(id: nil, event: nil, data: "first", retry: nil),
            SSEEvent(id: nil, event: nil, data: "second", retry: nil),
            SSEEvent(id: nil, event: nil, data: "third", retry: nil),
        ])
    }

    // MARK: - Comments

    func testCommentLines_areIgnored() async throws {
        let payload = """
        : this is a comment (heartbeat)
        data: actual event
        : another comment

        """
        let serializer = NetworkingSerializers.Stream.SSE()
        let stream = try await serializer.stream(byteStream: byteStream(yielding: [payload]),
                                                 urlResponse: URLResponse())
        let events = try await collect(stream)
        XCTAssertEqual(events, [
            SSEEvent(id: nil, event: nil, data: "actual event", retry: nil)
        ])
    }

    // MARK: - Empty events not dispatched

    func testEventsWithNoDataField_areNotDispatched() async throws {
        let payload = """
        event: orphan

        data: real

        """
        let serializer = NetworkingSerializers.Stream.SSE()
        let stream = try await serializer.stream(byteStream: byteStream(yielding: [payload]),
                                                 urlResponse: URLResponse())
        let events = try await collect(stream)
        XCTAssertEqual(events, [
            SSEEvent(id: nil, event: nil, data: "real", retry: nil)
        ], "Per spec, events with no data: fields are not dispatched")
    }

    // MARK: - Chunk boundaries

    func testEventSpanningMultipleChunks_isReassembled() async throws {
        // Event split mid-field and mid-line across multiple upstream Data chunks.
        let chunks = [
            "data: hel",
            "lo",
            "\ndata: wo",
            "rld\n",
            "\n", // blank line: dispatches the event
        ]
        let serializer = NetworkingSerializers.Stream.SSE()
        let stream = try await serializer.stream(byteStream: byteStream(yielding: chunks),
                                                 urlResponse: URLResponse())
        let events = try await collect(stream)
        XCTAssertEqual(events, [
            SSEEvent(id: nil, event: nil, data: "hello\nworld", retry: nil)
        ])
    }

    // MARK: - Line terminators

    func testCRLFLineTerminators_areHandled() async throws {
        let payload = "data: hello\r\ndata: world\r\n\r\n"
        let serializer = NetworkingSerializers.Stream.SSE()
        let stream = try await serializer.stream(byteStream: byteStream(yielding: [payload]),
                                                 urlResponse: URLResponse())
        let events = try await collect(stream)
        XCTAssertEqual(events, [
            SSEEvent(id: nil, event: nil, data: "hello\nworld", retry: nil)
        ])
    }

    func testBareCRLineTerminators_areHandled() async throws {
        // Per spec, bare CR (no LF after) is also a valid line terminator.
        let payload = "data: hello\rdata: world\r\r"
        let serializer = NetworkingSerializers.Stream.SSE()
        let stream = try await serializer.stream(byteStream: byteStream(yielding: [payload]),
                                                 urlResponse: URLResponse())
        let events = try await collect(stream)
        XCTAssertEqual(events, [
            SSEEvent(id: nil, event: nil, data: "hello\nworld", retry: nil)
        ], "Bare CR should split lines just like LF and CRLF")
    }

    func testCRSplitAcrossChunks_thenLF_isTreatedAsCRLF_notTwoLineTerminators() async throws {
        // A CR at the end of one chunk followed by LF at the start of the next must be
        // recognized as a single CRLF, not two bare-CR/bare-LF terminators.
        let chunks = ["data: hello\r", "\ndata: world\r\n", "\r\n"]
        let serializer = NetworkingSerializers.Stream.SSE()
        let stream = try await serializer.stream(byteStream: byteStream(yielding: chunks),
                                                 urlResponse: URLResponse())
        let events = try await collect(stream)
        XCTAssertEqual(events, [
            SSEEvent(id: nil, event: nil, data: "hello\nworld", retry: nil)
        ])
    }

    // MARK: - BOM stripping

    func testUTF8BOM_atStreamStart_isStripped() async throws {
        // UTF-8 BOM (EF BB BF) prepended to the payload. The serializer must strip it.
        var payload = Data([0xEF, 0xBB, 0xBF])
        payload.append(Data("data: hello\n\n".utf8))
        let serializer = NetworkingSerializers.Stream.SSE()
        let stream = try await serializer.stream(byteStream: byteStream(yielding: [payload]),
                                                 urlResponse: URLResponse())
        let events = try await collect(stream)
        XCTAssertEqual(events, [
            SSEEvent(id: nil, event: nil, data: "hello", retry: nil)
        ])
    }

    // MARK: - Value formatting

    func testColonWithNoSpaceAfter_keepsValueVerbatim() async throws {
        // Spec: only a single optional space after `:` is stripped.
        let payload = "data:no-space-here\n\n"
        let serializer = NetworkingSerializers.Stream.SSE()
        let stream = try await serializer.stream(byteStream: byteStream(yielding: [payload]),
                                                 urlResponse: URLResponse())
        let events = try await collect(stream)
        XCTAssertEqual(events, [
            SSEEvent(id: nil, event: nil, data: "no-space-here", retry: nil)
        ])
    }

    func testRetryFieldWithNonInteger_isIgnored() async throws {
        let payload = """
        retry: not-a-number
        data: payload

        """
        let serializer = NetworkingSerializers.Stream.SSE()
        let stream = try await serializer.stream(byteStream: byteStream(yielding: [payload]),
                                                 urlResponse: URLResponse())
        let events = try await collect(stream)
        XCTAssertEqual(events, [
            SSEEvent(id: nil, event: nil, data: "payload", retry: nil)
        ])
    }

    func testUnknownFields_areIgnored() async throws {
        let payload = """
        custom: value
        data: real

        """
        let serializer = NetworkingSerializers.Stream.SSE()
        let stream = try await serializer.stream(byteStream: byteStream(yielding: [payload]),
                                                 urlResponse: URLResponse())
        let events = try await collect(stream)
        XCTAssertEqual(events, [
            SSEEvent(id: nil, event: nil, data: "real", retry: nil)
        ])
    }

    // MARK: - EOF edge cases

    func testTrailingBareCRAtEOF_isTreatedAsTerminator_notValueContent() async throws {
        // Regression: a buffer ending in bare CR with no following byte must be treated as
        // a line terminator (per spec, bare CR terminates a line), NOT as a CR embedded in
        // the field's value. Earlier behavior absorbed `"data: x\r"` as the literal value
        // `"x\r"`, producing a corrupted event.
        let payload = "data: x\r"
        let serializer = NetworkingSerializers.Stream.SSE()
        let stream = try await serializer.stream(byteStream: byteStream(yielding: [payload]),
                                                 urlResponse: URLResponse())
        let events = try await collect(stream)
        XCTAssertEqual(events, [
            SSEEvent(id: nil, event: nil, data: "x", retry: nil)
        ])
    }

    // MARK: - Empty data values

    func testEmptyDataValue_dispatchesEventWithEmptyString() async throws {
        // Per spec, `data:` with no value still sets the event's data to "" — the event
        // dispatches because the data field IS set (just empty), not because of any field
        // count check.
        let payload = "data:\n\n"
        let serializer = NetworkingSerializers.Stream.SSE()
        let stream = try await serializer.stream(byteStream: byteStream(yielding: [payload]),
                                                 urlResponse: URLResponse())
        let events = try await collect(stream)
        XCTAssertEqual(events, [
            SSEEvent(id: nil, event: nil, data: "", retry: nil)
        ])
    }

    func testDataFieldWithNoColon_dispatchesEventWithEmptyString() async throws {
        // Per spec: a line with no colon is treated as a field name with an empty value.
        // `data` alone is therefore equivalent to `data:`.
        let payload = "data\n\n"
        let serializer = NetworkingSerializers.Stream.SSE()
        let stream = try await serializer.stream(byteStream: byteStream(yielding: [payload]),
                                                 urlResponse: URLResponse())
        let events = try await collect(stream)
        XCTAssertEqual(events, [
            SSEEvent(id: nil, event: nil, data: "", retry: nil)
        ])
    }

    func testMultiLineDataWithEmptyMiddleLine_joinsWithEmptyStringInPlace() async throws {
        // `data: a` + `data:` (empty) + `data: c` → joined with `\n` per spec → "a\n\nc".
        let payload = """
        data: a
        data:
        data: c

        """
        let serializer = NetworkingSerializers.Stream.SSE()
        let stream = try await serializer.stream(byteStream: byteStream(yielding: [payload]),
                                                 urlResponse: URLResponse())
        let events = try await collect(stream)
        XCTAssertEqual(events, [
            SSEEvent(id: nil, event: nil, data: "a\n\nc", retry: nil)
        ])
    }

    // MARK: - BOM edge cases

    func testUTF8BOMBytesAppearingMidStream_areNotStripped() async throws {
        // Only the BOM at the START of the stream is stripped. If the same byte sequence
        // appears later (e.g., in a data value), it's just bytes — keep them.
        let bom = Data([0xEF, 0xBB, 0xBF])
        var payload = Data("data: prefix".utf8)
        payload.append(bom)
        payload.append(Data(" suffix\n\n".utf8))
        let serializer = NetworkingSerializers.Stream.SSE()
        let stream = try await serializer.stream(byteStream: byteStream(yielding: [payload]),
                                                 urlResponse: URLResponse())
        let events = try await collect(stream)
        // The BOM bytes inside the data value decode as a literal BOM character (U+FEFF).
        let expectedData = "prefix\u{FEFF} suffix"
        XCTAssertEqual(events, [
            SSEEvent(id: nil, event: nil, data: expectedData, retry: nil)
        ], "Only a BOM at the very start of the stream is stripped; mid-stream BOM bytes are kept")
    }

    func testUTF8BOMSpanningChunkBoundary_isStillStripped() async throws {
        // BOM split across two upstream chunks — the parser must still recognize and strip
        // it once enough bytes have arrived.
        let chunks: [Data] = [
            Data([0xEF, 0xBB]),                  // first 2 BOM bytes only
            Data([0xBF]) + Data("data: hello\n\n".utf8) // 3rd BOM byte + actual content
        ]
        let serializer = NetworkingSerializers.Stream.SSE()
        let stream = try await serializer.stream(byteStream: byteStream(yielding: chunks),
                                                 urlResponse: URLResponse())
        let events = try await collect(stream)
        XCTAssertEqual(events, [
            SSEEvent(id: nil, event: nil, data: "hello", retry: nil)
        ])
    }
}
