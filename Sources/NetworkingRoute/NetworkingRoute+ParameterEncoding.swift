//
//  NetworkingResponseRoute+ParameterEncoding.swift
//
//  Created by Dan_Koza on 10/4/21.
//

import Foundation

/// ``NetworkingRouteParameterEncoding`` declares how your requests parameters should be added to a `URLRequest`.
///
/// For an in-depth look at how parameters are encoded you can look into ``URLEncoding`` and ``JSONEncoding``
public enum NetworkingRouteParameterEncoding: Sendable {

    /// Uses `JSONSerialization` to create a JSON representation of the parameters object, which is set as the body of the request. The Content-Type HTTP header field of an encoded request is set to application/json.
    case json(params: [String: Sendable]?,
              encoder: JSONEncoding = .default,
              urlParams: [String: Sendable]? = nil,
              urlEncoder: URLEncoding = .queryString)

    /// Sets the `URLRequest`'s httpBody to the associated value `encodedParams`.  The Content-Type HTTP header field of an encoded request is set to application/json.
    case jsonData(data: Data?,
                  encoder: JSONEncoding = .default,
                  urlParams: [String: Sendable]? = nil,
                  urlEncoder: URLEncoding = .queryString)

    /// Creates a url-encoded query string to be set as or appended to any existing URL query string or set as the HTTP body of the URL request. Whether the query string is set or appended to any existing URL query string or set as the HTTP body depends on the destination of the encoding.
    case url(params: [String: Sendable]?,
             encoder: URLEncoding = .default)

    /// Encodes the given parts as a `multipart/form-data` body. The Content-Type HTTP header field of an encoded request is set to `multipart/form-data; boundary=<boundary>`.
    case multipart(parts: [MultipartPart],
                   encoder: MultipartEncoding = .default,
                   urlParams: [String: Sendable]? = nil,
                   urlEncoder: URLEncoding = .queryString)

    /// Mutates a `URLRequest` by adding HTTP parameters
    /// - Parameter urlRequest: the `URLRequest` to add HTTP parameters to
    func encodeParams(into urlRequest: inout URLRequest) throws {
        switch self {
            case .url(let params, let urlEncoder):
                try urlEncoder.encode(&urlRequest, with: params)

            case .jsonData(let data, let jsonEncoder, let urlParams, let urlEncoder):
                jsonEncoder.encode(&urlRequest, with: data)
                try urlEncoder.encode(&urlRequest, with: urlParams)

            case .json(let params, let jsonEncoder, let urlParams, let urlEncoder):
                try jsonEncoder.encode(&urlRequest, with: params)
                try urlEncoder.encode(&urlRequest, with: urlParams)

            case .multipart(let parts, let multipartEncoder, let urlParams, let urlEncoder):
                try multipartEncoder.encode(&urlRequest, with: parts)
                try urlEncoder.encode(&urlRequest, with: urlParams)
        }
    }
}
