//
//  Stream+SSE.swift
//  PopNetworking
//

import Foundation

public extension NetworkingSerializers.Stream {

    /// A single event parsed from a Server-Sent Events (SSE) stream.
    ///
    /// Field mapping follows the WHATWG SSE spec:
    /// * ``id`` ← `id:` field
    /// * ``event`` ← `event:` field
    /// * ``data`` ← `data:` field(s), joined with `\n` when an event has multiple
    /// * ``retry`` ← `retry:` field, parsed as `Int`
    ///
    /// See: <https://html.spec.whatwg.org/multipage/server-sent-events.html>
    struct SSEEvent: Sendable, Equatable {

        /// The event's last-event-id, or `nil` if the server didn't send one. Consumers can
        /// stash this and pass it via the `Last-Event-ID` request header when re-iterating
        /// the route's stream, to ask the server to resume from the last seen event.
        public let id: String?

        /// The event's type name, or `nil` if the server didn't send an `event:` field.
        /// Per the SSE spec, browsers' `EventSource` treats a missing `event:` as the
        /// default `"message"` event type — consumers can apply the same default themselves
        /// (`event.event ?? "message"`).
        public let event: String?

        /// The event's payload. Multiple `data:` lines in one event are joined with `\n`.
        public let data: String

        /// Reconnection delay in milliseconds, or `nil` if the server didn't send one. The
        /// consumer is responsible for honoring this when re-iterating the stream.
        public let retry: Int?

        public init(id: String?, event: String?, data: String, retry: Int?) {
            self.id = id
            self.event = event
            self.data = data
            self.retry = retry
        }
    }

    /// Parses a Server-Sent Events (`text/event-stream`) byte stream into ``SSEEvent`` values.
    ///
    /// Behavior (per WHATWG SSE spec):
    /// * UTF-8 BOM (`EF BB BF`), if present, is stripped once at the start of the stream.
    /// * Line terminators: LF (`\n`), CR (`\r`), or CRLF (`\r\n`) are all recognized.
    /// * Lines starting with `:` are comments and skipped (commonly server heartbeats).
    /// * `field: value` sets a field on the in-progress event. An optional single space
    ///   after `:` is stripped.
    /// * A blank line dispatches the in-progress event if it has any `data:` fields.
    /// * Events without `data:` fields are not dispatched.
    /// * EOF flushes any pending event.
    ///
    /// Common use cases: LLM streaming APIs (OpenAI, Anthropic), real-time feeds,
    /// server-push dashboards.
    ///
    /// See: <https://html.spec.whatwg.org/multipage/server-sent-events.html>
    @available(iOS 15, macOS 12, tvOS 15, watchOS 8, visionOS 1, *)
    struct SSE: NetworkingStreamSerializer {

        public typealias Chunk = SSEEvent

        public init() {}

        public func stream(byteStream: AsyncThrowingStream<Foundation.Data, Error>,
                           urlResponse: URLResponse) async throws -> AsyncThrowingStream<SSEEvent, Error> {
            AsyncThrowingStream<SSEEvent, Error> { continuation in
                let task = Task {
                    var buffer = Foundation.Data()
                    var bomStripped = false
                    var builder = SSEEventBuilder()
                    do {
                        for try await chunk in byteStream {
                            try Task.checkCancellation()
                            buffer.append(chunk)

                            // BOM stripping — once, as soon as we have enough bytes to decide.
                            if !bomStripped, buffer.count >= utf8BOM.count {
                                if Array(buffer.prefix(utf8BOM.count)) == utf8BOM {
                                    buffer.removeFirst(utf8BOM.count)
                                }
                                bomStripped = true
                            }

                            while let line = SSEEventBuilder.consumeNextLine(from: &buffer) {
                                if line.isEmpty {
                                    // Blank line: dispatch the in-progress event.
                                    if let event = builder.build() {
                                        continuation.yield(event)
                                    }
                                    builder = SSEEventBuilder()
                                } else if line.first == .colon {
                                    // Comment line (heartbeat / keep-alive). Skip per spec.
                                    continue
                                } else {
                                    builder.absorb(line: String(decoding: line, as: UTF8.self))
                                }
                            }
                        }
                        // EOF: any bytes remaining in the buffer are a final line that
                        // never got a terminator while bytes were streaming. A trailing CR
                        // is one such terminator — we couldn't disambiguate it from CRLF
                        // earlier, but EOF tells us no LF is coming, so strip it before
                        // treating what remains as the final line's content.
                        if buffer.last == .carriageReturn {
                            buffer = buffer.dropLast()
                        }
                        if !buffer.isEmpty {
                            if buffer.first == .colon {
                                // Trailing comment — ignore.
                            } else {
                                builder.absorb(line: String(decoding: buffer, as: UTF8.self))
                            }
                        }
                        if let event = builder.build() {
                            continuation.yield(event)
                        }
                        continuation.finish()
                    } catch {
                        continuation.finish(throwing: error)
                    }
                }
                continuation.onTermination = { _ in task.cancel() }
            }
        }
    }
}

/// Accumulator for the in-progress SSE event being built field-by-field. `data:` fields
/// concatenate with `\n` per the spec; other fields overwrite (the last `id:` / `event:` /
/// `retry:` in an event wins).
private struct SSEEventBuilder {
    var id: String?
    var event: String?
    var dataLines: [String] = []
    var retry: Int?

    mutating func absorb(line: String) {
        // Per spec: split on the FIRST colon. If no colon, the whole line is the field name
        // with an empty value.
        let field: String
        let rawValue: String
        if let colonRange = line.range(of: ":") {
            field = String(line[line.startIndex..<colonRange.lowerBound])
            // Strip a single optional leading space on the value (per spec).
            var valueStart = colonRange.upperBound
            if valueStart < line.endIndex, line[valueStart] == " " {
                valueStart = line.index(after: valueStart)
            }
            rawValue = String(line[valueStart..<line.endIndex])
        } else {
            field = line
            rawValue = ""
        }

        switch field {
            case "id":
                self.id = rawValue
            case "event":
                self.event = rawValue
            case "data":
                self.dataLines.append(rawValue)
            case "retry":
                if let value = Int(rawValue) { self.retry = value }
            default:
                break // Unknown fields are silently ignored per the spec.
        }
    }

    /// Builds an event from the accumulated fields, or returns `nil` if the event has no
    /// `data:` fields (per spec, events without data are not dispatched).
    func build() -> NetworkingSerializers.Stream.SSEEvent? {
        guard !self.dataLines.isEmpty else { return nil }
        return NetworkingSerializers.Stream.SSEEvent(
            id: self.id,
            event: self.event,
            data: self.dataLines.joined(separator: "\n"),
            retry: self.retry
        )
    }

    /// Pops the next complete line from the buffer if one is fully available, treating LF,
    /// CR, or CRLF as terminators. Returns `nil` if no complete line is present yet — in
    /// particular, a buffer ending in lone CR (could still become CRLF when more bytes
    /// arrive) is treated as incomplete to avoid splitting CRLF across chunks.
    static func consumeNextLine(from buffer: inout Foundation.Data) -> Foundation.Data? {
        var i = buffer.startIndex
        while i < buffer.endIndex {
            let byte = buffer[i]
            if byte == .lineFeed {
                let line = Foundation.Data(buffer[buffer.startIndex..<i])
                buffer.removeSubrange(buffer.startIndex...i)
                return line
            }
            if byte == .carriageReturn {
                let next = buffer.index(after: i)
                if next == buffer.endIndex {
                    // CR at the end of buffer — could be the first half of CRLF that
                    // hasn't arrived yet. Wait for more bytes.
                    return nil
                }
                let line = Foundation.Data(buffer[buffer.startIndex..<i])
                if buffer[next] == .lineFeed {
                    // CRLF — consume both.
                    buffer.removeSubrange(buffer.startIndex...next)
                } else {
                    // Bare CR — consume the CR only.
                    buffer.removeSubrange(buffer.startIndex...i)
                }
                return line
            }
            i = buffer.index(after: i)
        }
        return nil
    }
}
