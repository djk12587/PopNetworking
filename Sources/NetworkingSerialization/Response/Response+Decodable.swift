//
//  Response+Decodable.swift
//  PopNetworking
//

import Foundation

public extension NetworkingSerializers.Response {

    /// Parses response `Data` into the generic `SuccessType` using a `JSONDecoder`.
    ///
    /// - Note: Does not surface API-shaped error bodies as typed errors. For that, use
    ///   ``DecodableAndError``.
    struct Decodable<SuccessType: Swift.Decodable & Sendable>: NetworkingResponseSerializer {

        public typealias SerializedObject = SuccessType

        private let jsonDecoder: JSONDecoder

        /// - Parameter jsonDecoder: The `JSONDecoder` used to parse the response body.
        public init(jsonDecoder: JSONDecoder = JSONDecoder()) {
            self.jsonDecoder = jsonDecoder
        }

        public func serialize(responseResult: Result<(Foundation.Data, URLResponse), Error>) async -> Result<SuccessType, Error> {
            return responseResult.flatMap { (responseData, _) in
                Result { try self.jsonDecoder.decode(SerializedObject.self, from: responseData) }
            }
        }
    }
}
