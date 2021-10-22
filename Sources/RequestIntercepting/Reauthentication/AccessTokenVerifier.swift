//
//  File.swift
//  
//
//  Created by Dan_Koza on 10/21/21.
//

import Foundation

public protocol AccessTokenVerification {
    associatedtype ReauthenticationRoute: NetworkingRoute
    var reauthenticationRoute: ReauthenticationRoute { get }

    var accessToken: String { get }
    var tokenIsExpired: Bool { get }
    var tokenType: String { get }

    func extractAuthorizationHeaderKey(from urlRequest: URLRequest) -> String?
    func extractAuthorizationHeaderValue(from urlRequest: URLRequest) -> String?

    func shouldRetry(urlRequest: URLRequest, dueTo error: Error, urlResponse: HTTPURLResponse, retryCount: Int) -> Bool
    mutating func reauthentication(result: Result<ReauthenticationRoute.ResponseSerializer.SerializedObject, Error>)
}

public extension AccessTokenVerification {
    var tokenType: String { "Bearer" }

    func extractAuthorizationHeaderValue(from urlRequest: URLRequest) -> String? {
        guard let authorizationHeaderKey = extractAuthorizationHeaderKey(from: urlRequest) else { return nil }
        return urlRequest.allHTTPHeaderFields?[authorizationHeaderKey]
    }
}
