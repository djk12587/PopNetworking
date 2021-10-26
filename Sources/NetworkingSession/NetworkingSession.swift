//
//  Networking+Session.swift
//  PopNetworking
//
//  Created by Daniel Koza on 1/8/21.
//  Copyright © 2021 Daniel Koza. All rights reserved.
//

import Foundation

// MARK: - NetworkingSession

public extension NetworkingSession {
    /// A singleton ``NetworkingSession`` object.
    ///
    /// For basic requests, the ``NetworkingSession`` class provides a shared singleton session object that gives you a reasonable default behavior for creating tasks. Note: the ``NetworkingSession/shared`` instance does not utilize a ``NetworkingRequestAdapter`` or ``NetworkingRequestRetrier``
    static let shared = NetworkingSession()
}


/// Is  a wrapper class for `URLSession`.  This class takes a ``NetworkingRoute`` and performs an HTTP request.
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
    /// All `URLRequest`'s will be passed through the supplied instance of ``AccessTokenVerification``
    public init<AccessTokenVerifier: AccessTokenVerification>(session: URLSession = URLSession(configuration: .default), accessTokenVerifier: AccessTokenVerifier) {
        self.session = session
        let requestInterceptor = ReauthenticationHandler(accessTokenVerifier: accessTokenVerifier)
        self.requestAdapter = requestInterceptor
        self.requestRetrier = requestInterceptor
    }

    /// Performs an HTTP request for  a ``NetworkingRoute``
    /// - Parameters:
    ///     - route: The ``NetworkingRoute`` you want to execute.
    ///     - queue: The `DispatchQueue` that your `completionHandler` will be executed on. By default, `DispatchQueue.main` is used.
    ///     - completionHandler:  Once the ``NetworkingRoute`` is completed, the `completionHandler` will be executed with the specified ``NetworkingResponseSerializer/SerializedObject`` or an `Error`
    /// - Returns: A ``Cancellable`` which can be used to cancel a request that is waiting for a result.
    public func execute<Route: NetworkingRoute>(route: Route,
                                                runCompletionHandlerOn queue: DispatchQueue = .main,
                                                completionHandler: @escaping (Result<Route.ResponseSerializer.SerializedObject, Error>) -> Void) -> Cancellable {
        if let mockResponse = route.mockResponse {
            queue.async { completionHandler(mockResponse) }
            return MockedCancellable()
        }
        else {
            let routeDataTask = RouteDataTask(route: route,
                                              requestAdapter: requestAdapter,
                                              requestRetrier: requestRetrier,
                                              routeDataTaskDelegate: self,
                                              completionHandlerQueue: queue,
                                              routeCompletionHandler: completionHandler)
            execute(routeDataTask)
            return routeDataTask
        }
    }

    private func execute<Route: NetworkingRoute>(_ routeDataTask: RouteDataTask<Route>) {
        do {
            let urlRequest = try routeDataTask.urlRequest
            let urlSessionDataTask = session.dataTask(with: urlRequest) { (responseData, response, error) in
                routeDataTask.executeResponseSerializer(with: URLSessionDataTask.RawResponse(urlRequest: urlRequest,
                                                                                             urlResponse: response as? HTTPURLResponse,
                                                                                             data: responseData,
                                                                                             error: error))
            }

            routeDataTask.urlSessionDataTask = urlSessionDataTask
            urlSessionDataTask.resume()
        } catch {
            routeDataTask.executeResponseSerializer(with: URLSessionDataTask.RawResponse(urlRequest: nil,
                                                                                         urlResponse: nil,
                                                                                         data: nil,
                                                                                         error: error))
        }
    }
}

extension NetworkingSession: NetworkingRouteDataTaskDelegate {
    internal func retry<Route: NetworkingRoute>(routeDataTask: RouteDataTask<Route>) {
        execute(routeDataTask)
    }
}
