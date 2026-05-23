//
//  Stream+Data.swift
//  PopNetworking
//

import Foundation

public extension NetworkingSerializers.Stream {

    /// Forwards each upstream `Data` chunk to the consumer unchanged. No parsing, no
    /// transformation — the consumer sees the raw bytes as they arrive from the network.
    ///
    /// Useful for raw binary streams (file downloads, custom protocols) where the consumer
    /// wants the bytes verbatim. Chunk size is governed by
    /// ``NetworkingStreamRoute/byteChunkSize`` (default 16 KB).
    @available(iOS 15, macOS 12, tvOS 15, watchOS 8, visionOS 1, *)
    struct Data: NetworkingStreamSerializer {

        public typealias Chunk = Foundation.Data

        public init() {}

        public func stream(byteStream: AsyncThrowingStream<Foundation.Data, Error>,
                           urlResponse: URLResponse) async throws -> AsyncThrowingStream<Foundation.Data, Error> {
            return byteStream
        }
    }
}
