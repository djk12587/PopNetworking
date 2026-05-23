//
//  Response+HttpStatusCode.swift
//  PopNetworking
//

import Foundation

public extension NetworkingSerializers.Response {

    /// Returns the `HTTPURLResponse.statusCode` as an `Int`.
    struct HttpStatusCode: NetworkingResponseSerializer {

        public typealias SerializedObject = Int

        public init() {}

        public func serialize(responseResult: Result<(Foundation.Data, URLResponse), Error>) async -> Result<Int, Error> {
            return responseResult.flatMap { (_, urlResponse) in
                guard let httpUrlResponse = urlResponse as? HTTPURLResponse else {
                    return .failure(URLError(.badServerResponse, userInfo: ["Reason": "urlResponse was nil"]))
                }
                return .success(httpUrlResponse.statusCode)
            }
        }
    }
}
