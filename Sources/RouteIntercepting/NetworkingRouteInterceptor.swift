//
//  Networking+RequestInterceptor.swift
//  PopNetworking
//
//  Created by Daniel Koza on 1/9/21.
//  Copyright © 2021 Daniel Koza. All rights reserved.
//

import Foundation

/// Allows you to mutate a request before it gets sent, and retry `URLRequest`'s that failed.
/// - Note:
///   Common use case: refreshing authorization tokens
public protocol NetworkingRouteInterceptor: NetworkingRouteAdapter & NetworkingRouteRetrier {}

/// Allows you to adapt, or modify, the `URLRequest` before it gets executed as an HTTP request.
public protocol NetworkingRouteAdapter: Sendable {

    /// A throwable function that accepts a `URLRequest` and will return a potentially modified `URLRequest` or throw an `Error`
    /// - Parameters:
    ///   - urlRequest: Modify this `URLRequest` object if necessary. If no modifications are required simply return the `urlRequest`.
    ///
    /// - Returns: The adapted or modified `URLRequest`.
    func adapt(urlRequest: URLRequest) async throws -> URLRequest
}

/// Allows you to retry a failed `URLRequest`. IE, if the `URLRequest` failed due to a 401 Unauthorized error.
public protocol NetworkingRouteRetrier: Sendable {
    /// A function that will determine if a `URLRequest` should be retried or not.
    ///
    /// - Parameters:
    ///   - urlRequest: The `URLRequest` object that failed.
    ///   - error: The reason the `URLRequest` failed.
    ///   - urlResponse: The failed `URLRequest`'s response.
    ///   - retryCount: The number of times this `URLRequest` has been retried.
    ///
    ///   - Returns: An instance of ``NetworkingRouteRetrierResult`` which indicates if the request should be retried or not
    func retry(urlRequest: URLRequest?,
               dueTo error: Error,
               urlResponse: URLResponse?,
               retryCount: Int) async -> NetworkingRouteRetrierResult
}

/// `NetworkingRouteRetrierResult`indicates if a request should be retried or not. `NetworkingRouteRetrierResult` is returned from ``NetworkingRouteRetrier/retry(urlRequest:dueTo:urlResponse:retryCount:)``.
public enum NetworkingRouteRetrierResult: Sendable {
    case retry
    case retryWithDelay(TimeInterval)
    case doNotRetry
}
