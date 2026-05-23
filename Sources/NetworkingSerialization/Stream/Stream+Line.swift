//
//  Stream+Line.swift
//  PopNetworking
//

import Foundation

public extension NetworkingSerializers.Stream {

    /// Splits the upstream byte stream into UTF-8 strings on each `\n`. The trailing `\r`
    /// of a CRLF line ending is stripped before decoding, so consumers see the same line
    /// content whether the server uses `\n` or `\r\n`.
    ///
    /// A trailing partial line (bytes received without a final newline before EOF) is
    /// yielded as the final element.
    @available(iOS 15, macOS 12, tvOS 15, watchOS 8, visionOS 1, *)
    struct Line: NetworkingStreamSerializer {

        public typealias Chunk = String

        public init() {}

        public func stream(byteStream: AsyncThrowingStream<Foundation.Data, Error>,
                           urlResponse: URLResponse) async throws -> AsyncThrowingStream<String, Error> {
            AsyncThrowingStream<String, Error> { continuation in
                let task = Task {
                    var buffer = Foundation.Data()
                    do {
                        for try await chunk in byteStream {
                            try Task.checkCancellation()
                            buffer.append(chunk)
                            while let newlineIndex = buffer.firstIndex(of: .lineFeed) {
                                // Strip a single trailing CR so CRLF and LF lines decode identically.
                                let lineEnd: Foundation.Data.Index
                                if newlineIndex > buffer.startIndex,
                                   buffer[buffer.index(before: newlineIndex)] == .carriageReturn {
                                    lineEnd = buffer.index(before: newlineIndex)
                                } else {
                                    lineEnd = newlineIndex
                                }
                                let lineData = buffer[buffer.startIndex..<lineEnd]
                                buffer.removeSubrange(buffer.startIndex...newlineIndex)
                                continuation.yield(String(decoding: lineData, as: UTF8.self))
                            }
                        }
                        // Trailing partial line (no terminating newline).
                        if !buffer.isEmpty {
                            let tail: Foundation.Data
                            if buffer.last == .carriageReturn {
                                tail = buffer.dropLast()
                            } else {
                                tail = buffer
                            }
                            continuation.yield(String(decoding: tail, as: UTF8.self))
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
