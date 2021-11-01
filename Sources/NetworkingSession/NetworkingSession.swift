//
//  Networking+Session.swift
//  PopNetworking
//
//  Created by Daniel Koza on 1/8/21.
//  Copyright © 2021 Daniel Koza. All rights reserved.
//

import Foundation
import CoreVideo

// MARK: - NetworkingSession

public extension NetworkingSession {
    /// A singleton ``NetworkingSession`` object.
    ///
    /// For basic requests, the ``NetworkingSession`` class provides a shared singleton session object that gives you a reasonable default behavior for creating tasks. Note: the ``NetworkingSession/shared`` instance does not utilize a ``NetworkingRequestAdapter`` or ``NetworkingRequestRetrier``
    static let shared = NetworkingSession()
}


/// Is  a wrapper class for `URLSession`. This class takes a ``NetworkingRoute`` and kicks off the HTTP request.
public class NetworkingSession {

    private let session: URLSession
    private let requestAdapter: NetworkingRequestAdapter?
    private let requestRetrier: NetworkingRequestRetrier?

    /// Creates an instance of a ``NetworkingSession``
    /// - Parameters:
    ///   - session: The underlying `URLSession` used to make an HTTP request. By default, a `URLSession` is configured with the `.default` `URLSessionConfiguration`
    ///   - requestAdapter: Responsible to modifying a `URLRequest` before being executed. See ``NetworkingRequestAdapter``
    ///   - requestRetrier: Responsible for retrying a failed `URLRequest`. See ``NetworkingRequestRetrier``
    public init(session: URLSession = URLSession(configuration: .default),
                requestAdapter: NetworkingRequestAdapter? = nil,
                requestRetrier: NetworkingRequestRetrier? = nil) {
        self.session = session
        self.requestAdapter = requestAdapter
        self.requestRetrier = requestRetrier
    }

    /// Creates an instance of a ``NetworkingSession`` with an instance of ``AccessTokenVerification``
    /// - Parameters:
    ///   - session: The underlying `URLSession` used to make an HTTP request. By default, a `URLSession` is configured with the `.default` `URLSessionConfiguration`
    ///   - accessTokenVerifier: See ``AccessTokenVerification``
    ///
    /// - Note: Pass in an ``AccessTokenVerification`` if you want to automatically reauthenticate network requests when your access token is expired.
    public init<AccessTokenVerifier: AccessTokenVerification>(session: URLSession = URLSession(configuration: .default), accessTokenVerifier: AccessTokenVerifier) {
        self.session = session
        let requestInterceptor = ReauthenticationHandler(accessTokenVerifier: accessTokenVerifier)
        self.requestAdapter = requestInterceptor
        self.requestRetrier = requestInterceptor
    }

    /// Performs an HTTP request and parses the HTTP response into a `Result<Route.ResponseSerializer.SerializedObject, Error>`
    /// - Parameters:
    ///     - route: The ``NetworkingRoute`` you want to execute.
    ///     - queue: The `DispatchQueue` that your `completionHandler` will be executed on. By default, `DispatchQueue.main` is used.
    ///     - completionHandler:  Once the ``NetworkingRoute`` is completed, the `completionHandler` will be executed with the specified ``NetworkingResponseSerializer/SerializedObject`` or an `Error`
    /// - Returns: A ``Cancellable`` which can be used to cancel a request that is running.
    public func execute<Route: NetworkingRoute>(route: Route) -> Task<Route.ResponseSerializer.SerializedObject, Error> {
        Task {
            if let mockResponse = route.mockResponse {
                return try mockResponse.get()
            }
            else {
                return try await execute(RouteDataTask(route: route, requestAdapter: requestAdapter)).get()
            }
        }
    }

    private func execute<Route: NetworkingRoute>(_ routeDataTask: RouteDataTask<Route>) async -> Result<Route.ResponseSerializer.SerializedObject, Error> {
        do {
            let urlRequest = try routeDataTask.urlRequest
            let (responseData, response, responseError) = await session.dataTask(for: urlRequest)
            let rawResponse = URLSessionDataTask.RawResponse(urlRequest: urlRequest,
                                                             urlResponse: response as? HTTPURLResponse,
                                                             data: responseData,
                                                             error: responseError)
            let serializedResult = routeDataTask.executeResponseSerializer(with: rawResponse)
            return await retry(routeDataTask: routeDataTask,
                               urlRequest: urlRequest,
                               rawResponse: rawResponse,
                               serializedResult: serializedResult)
        } catch {
            let serializedResult = routeDataTask.executeResponseSerializer(with: URLSessionDataTask.RawResponse(urlRequest: nil,
                                                                                                                urlResponse: nil,
                                                                                                                data: nil,
                                                                                                                error: error))
            return await retry(routeDataTask: routeDataTask,
                               urlRequest: nil,
                               rawResponse: nil,
                               serializedResult: serializedResult)
        }
    }

    private func retry<Route: NetworkingRoute>(routeDataTask: RouteDataTask<Route>,
                                               urlRequest: URLRequest?,
                                               rawResponse: URLSessionDataTask.RawResponse?,
                                               serializedResult: Result<Route.ResponseSerializer.SerializedObject, Error>) async -> Result<Route.ResponseSerializer.SerializedObject, Error> {
        guard
            let error = rawResponse?.error ?? serializedResult.error,
            let retrier = requestRetrier
        else {
            return serializedResult
        }

        switch await retrier.retry(urlRequest: urlRequest,
                                   dueTo: error,
                                   urlResponse: rawResponse?.urlResponse,
                                   retryCount: routeDataTask.retryCount) {
            case .retry:
                routeDataTask.incrementRetryCount()
                return await execute(routeDataTask)
            case .doNotRetry:
                return serializedResult
        }
    }
}

private extension URLSession {
    func dataTask(for urlRequest: URLRequest) async -> (Data?, URLResponse?, Error?) {
        let dataTaskResponse: (Data?, URLResponse?, Error?) = await withCheckedContinuation { continuation in
            let dataTask = dataTask(with: urlRequest) { (responseData, response, error) in
                continuation.resume(returning: (responseData, response, error))
            }
            dataTask.resume()
        }
        return dataTaskResponse
    }
}

private extension Result {
    var error: Error? {
        guard case let .failure(error) = self else { return nil }
        return error
    }
}
