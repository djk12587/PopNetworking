//
//  Stream+Decodable.swift
//  PopNetworking
//

import Foundation

public extension NetworkingSerializers.Stream {

    /// Parses a newline-delimited JSON (NDJSON / JSON Lines) byte stream into one
    /// `Decodable` value per `\n`-terminated line.
    ///
    /// Each non-empty line is decoded individually as `Element` using the supplied
    /// `JSONDecoder`. Mid-stream decode failures finish the returned stream with the
    /// decoder's error; chunks already delivered to the consumer remain valid.
    ///
    /// Empty lines (consecutive newlines) are skipped — they're a common artifact of
    /// servers padding the stream.
    @available(iOS 15, macOS 12, tvOS 15, watchOS 8, visionOS 1, *)
    struct Decodable<Element: Swift.Decodable & Sendable>: NetworkingStreamSerializer {

        public typealias Chunk = Element

        private let decoder: JSONDecoder

        /// - Parameter decoder: The `JSONDecoder` used to parse each line into `Element`.
        public init(decoder: JSONDecoder = JSONDecoder()) {
            self.decoder = decoder
        }

        public func stream(byteStream: AsyncThrowingStream<Foundation.Data, Error>,
                           urlResponse: URLResponse) async throws -> AsyncThrowingStream<Element, Error> {
            let decoder = self.decoder
            return AsyncThrowingStream<Element, Error> { continuation in
                let task = Task {
                    var buffer = Foundation.Data()
                    do {
                        for try await chunk in byteStream {
                            try Task.checkCancellation()
                            buffer.append(chunk)
                            while let newlineIndex = buffer.firstIndex(of: .lineFeed) {
                                // Strip a single trailing CR so CRLF and LF both work.
                                let lineEnd: Foundation.Data.Index
                                if newlineIndex > buffer.startIndex,
                                   buffer[buffer.index(before: newlineIndex)] == .carriageReturn {
                                    lineEnd = buffer.index(before: newlineIndex)
                                } else {
                                    lineEnd = newlineIndex
                                }
                                let lineData = Foundation.Data(buffer[buffer.startIndex..<lineEnd])
                                buffer.removeSubrange(buffer.startIndex...newlineIndex)

                                if lineData.isEmpty { continue }
                                let value = try decoder.decode(Element.self, from: lineData)
                                continuation.yield(value)
                            }
                        }
                        // Trailing partial line without a terminating newline.
                        if !buffer.isEmpty {
                            let tail: Foundation.Data
                            if buffer.last == .carriageReturn {
                                tail = buffer.dropLast()
                            } else {
                                tail = buffer
                            }
                            if !tail.isEmpty {
                                let value = try decoder.decode(Element.self, from: tail)
                                continuation.yield(value)
                            }
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
