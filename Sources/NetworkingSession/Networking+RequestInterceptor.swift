//
//  Networking+RequestInterceptor.swift
//  PopNetworking
//
//  Created by Daniel Koza on 1/9/21.
//  Copyright © 2021 Daniel Koza. All rights reserved.
//

import Foundation

/// A common use case for a `NetworkingRequestInterceptor` is to reauthenticate an expired OAuth token.
public protocol NetworkingRequestInterceptor: NetworkingRequestAdapter & NetworkingRequestRetrier {}

public protocol NetworkingRequestAdapter {
    /// Allows you to adapt, or modify, the `URLRequest` before it gets sent over the wire.
    ///
    /// - Parameters:
    ///   - urlRequest: Modify this `URLRequest` object if necessary. If no modifications are required simply return the `urlRequest`.
    ///   - session: This is the `URLSession` that the `urlRequest` will be sent over the wire on.
    ///
    /// - Returns: The `URLRequest` that is returned is what will be sent over the wire. Any errors thrown here will attempt to call the `NetworkingRequestRetrier` `retry()` function
    func adapt(urlRequest: URLRequest, for session: URLSession) throws -> URLRequest
}

public protocol NetworkingRequestRetrier: class {
    /// Allows you to retry a failed `URLRequest`.
    ///
    /// - Parameters:
    ///   - urlRequest: The `URLRequest` object that failed.
    ///   - error: The reason the `urlRequest` failed.
    ///   - urlResponse: The failed `urlRequest`'s response.
    ///   - retryCount: The number of times this `urlRequest` has been retried.
    ///   - completion: Pass in a `NetworkingRequestRetrierResult` to the completion block. `NetworkingRequestRetrierResult` determines if the `urlRequest` will be retried or not.
    func retry(urlRequest: URLRequest,
               dueTo error: Error,
               urlResponse: HTTPURLResponse,
               retryCount: Int,
               completion: @escaping (NetworkingRequestRetrierResult) -> Void)
}

public enum NetworkingRequestRetrierResult {
    case retry
    case doNotRetry
}
