//
//  Response+Empty.swift
//  PopNetworking
//

import Foundation

public extension NetworkingSerializers.Response {

    /// Discards the response body and returns `Void` on success.
    ///
    /// Use for routes whose body you don't care about: `HEAD` requests, endpoints that
    /// respond with `204 No Content` / `205 Reset Content`, etc.
    struct Empty: NetworkingResponseSerializer {

        public typealias SerializedObject = Void

        public init() {}

        public func serialize(responseResult: Result<(Foundation.Data, URLResponse), Error>) async -> Result<Void, Error> {
            responseResult.map { _ in () }
        }
    }
}
