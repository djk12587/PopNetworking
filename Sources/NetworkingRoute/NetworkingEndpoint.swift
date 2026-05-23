//
//  NetworkingEndpoint.swift
//  PopNetworking
//

import Foundation

/// ``NetworkingEndpoint`` describes a single HTTP call: where to send it, how to encode it,
/// and which session executes it.
///
/// It is the shared base for ``NetworkingResponseRoute`` (single request/response) and
/// ``NetworkingStreamRoute`` (incremental response). Anything that participates in
/// building a `URLRequest` lives here. Hooks attached to the call (adapters, observers)
/// live on ``NetworkingHooks``; response-handling specifics live on the route protocols.
public protocol NetworkingEndpoint: Sendable {

    typealias NetworkingRouteHttpHeaders = [String : String]

    /// The ``NetworkingSessionProtocol`` used to execute the endpoint.
    var session: NetworkingSessionProtocol { get }

    /// Declares the base URL.
    var baseUrl: String { get }
    /// Declares the path of the URL.
    var path: String { get }
    /// Declares the HTTP method.
    var method: NetworkingRouteHttpMethod { get }
    /// Declares the request headers.
    var headers: NetworkingRouteHttpHeaders? { get }

    /// The parameter encoding strategy used when building the `URLRequest`.
    var parameterEncoding: NetworkingRouteParameterEncoding? { get }

    /// Builds the `URLRequest` that will be executed.
    ///                 
    /// - Note: This is `async throws` so overrides can perform async work (e.g. fetching an auth token)
    /// when assembling the request. The default implementation is purely synchronous.
    var urlRequest: URLRequest { get async throws }

    /// Used by ``urlRequest``'s default implementation when constructing the `URLRequest`.
    ///
    /// - Note: If `nil`, 60 seconds is used.
    var timeoutInterval: TimeInterval? { get }
}

public extension NetworkingEndpoint {

    /// Default implementation. Override if you need to build the request asynchronously
    /// (e.g. fetching an auth token before encoding).
    var urlRequest: URLRequest {
        get async throws {
            guard let baseURL = URL(string: self.baseUrl) else {
                throw URLError(.badURL, userInfo: ["baseUrl": self.baseUrl])
            }
            let url = self.path.isEmpty ? baseURL : baseURL.appendingPathComponent(self.path)

            var mutableRequest = URLRequest(url: url, timeoutInterval: self.timeoutInterval ?? 60.0)
            mutableRequest.httpMethod = self.method.rawValue
            try self.parameterEncoding?.encodeParams(into: &mutableRequest)
            self.headers?.forEach { mutableRequest.setValue($0.value, forHTTPHeaderField: $0.key) }
            return mutableRequest
        }
    }

    var session: NetworkingSessionProtocol { NetworkingSession.shared }
    var headers: NetworkingRouteHttpHeaders? { nil }
    var parameterEncoding: NetworkingRouteParameterEncoding? { nil }
    var timeoutInterval: TimeInterval? { nil }
}
