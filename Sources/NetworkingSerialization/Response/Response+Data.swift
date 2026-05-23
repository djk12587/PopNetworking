//
//  Response+Data.swift
//  PopNetworking
//

import Foundation

public extension NetworkingSerializers.Response {

    /// Returns the raw networking `Data` from an HTTP response, unmodified.
    struct Data: NetworkingResponseSerializer {

        public typealias SerializedObject = Foundation.Data

        public init() {}

        public func serialize(responseResult: Result<(Foundation.Data, URLResponse), Error>) async -> Result<Foundation.Data, Error> {
            responseResult.map({ $0.0 })
        }
    }
}
