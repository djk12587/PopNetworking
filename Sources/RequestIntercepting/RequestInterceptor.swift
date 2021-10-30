//
//  Networking+RequestInterceptor.swift
//  PopNetworking
//
//  Created by Daniel Koza on 1/9/21.
//  Copyright © 2021 Daniel Koza. All rights reserved.
//

import Foundation

/// Allows you the ability to mutate a request before it gets sent, and retry `URLRequest`'s that failed.
public protocol NetworkingRequestInterceptor: NetworkingRequestAdapter & NetworkingRequestRetrier {}

/// Allows you to adapt, or modify, the `URLRequest` before it gets executed as an HTTP request.
public protocol NetworkingRequestAdapter: AnyObject {

    /// A throwable function that accepts a `URLRequest` and will return a potentially modifed `URLRequest` or throw an `Error`
    /// - Parameters:
    ///   - urlRequest: Modify this `URLRequest` object if necessary. If no modifications are required simply return the `urlRequest`.
    ///
    /// - Returns: The `URLRequest` that is returned is what will be sent over the wire. Any errors thrown here will attempt to call the `NetworkingRequestRetrier` `retry()` function
    func adapt(urlRequest: URLRequest) throws -> URLRequest
}

/// Allows you to retry a failed `URLRequest`. IE, if the `URLRequest` failed due to a 401 Unauthorized error.
public protocol NetworkingRequestRetrier: AnyObject {
    /// A function that will determine if a `URLRequest` should be retried or not.
    ///
    /// - Parameters:
    ///   - urlRequest: The `URLRequest` object that failed.
    ///   - error: The reason the `URLRequest` failed.
    ///   - urlResponse: The failed `URLRequest`'s response.
    ///   - retryCount: The number of times this `URLRequest` has been retried.
    ///   - completion: Pass in a ``NetworkingRequestRetrierResult`` to the completion block. ``NetworkingRequestRetrierResult`` determines if the `urlRequest` will be retried or not.
    func retry(urlRequest: URLRequest,
               dueTo error: Error,
               urlResponse: HTTPURLResponse,
               retryCount: Int,
               completion: @escaping (NetworkingRequestRetrierResult) -> Void)

    @available(macOS 10.15.0, *)
    func retry2(urlRequest: URLRequest,
                dueTo error: Error,
                urlResponse: HTTPURLResponse,
                retryCount: Int) async -> NetworkingRequestRetrierResult
}

public enum NetworkingRequestRetrierResult {
    case retry
    case doNotRetry
}
