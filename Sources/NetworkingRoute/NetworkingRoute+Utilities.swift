//
//  File.swift
//  
//
//  Created by Dan_Koza on 10/4/21.
//

import Foundation

/// ``NetworkingRequestParameterEncoding`` declares how your requests parameters should be added to a `URLRequest`.
///
/// For an indepth look at how parameters are encoded you can look into ``URLEncoding`` and ``JSONEncoding``
public enum NetworkingRequestParameterEncoding {
    /// Uses `JSONSerialization` to create a JSON representation of the parameters object, which is set as the body of the request. The Content-Type HTTP header field of an encoded request is set to application/json.
    case json(params: [String: Any]?)

    /// Sets the `URLRequest`'s httpBody to the associated value `encodedParams`.  The Content-Type HTTP header field of an encoded request is set to application/json.
    case jsonData(encodedParams: Data?)

    /// Creates a url-encoded query string to be set as or appended to any existing URL query string or set as the HTTP body of the URL request. Whether the query string is set or appended to any existing URL query string or set as the HTTP body depends on the destination of the encoding.
    case url(params: [String: Any]?)

    /// Mutates a `URLRequest` by adding HTTP parameters
    /// - Parameter urlRequest: the `URLRequest` to add HTTP parameters to
    func encodeParams(into urlRequest: inout URLRequest) throws {
        switch self {
            case .url(let params):
                try URLEncoding.default.encode(&urlRequest, with: params)

            case .json(let params):
                try JSONEncoding.default.encode(&urlRequest, with: params)

            case .jsonData(let encodedParams):
                JSONEncoding.default.encode(&urlRequest, with: encodedParams)
        }
    }
}

public enum NetworkingRouteHttpMethod: String {
    case get
    case post
    case delete
    case put
    case patch
}
