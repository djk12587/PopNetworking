//
//  Networking+Session.swift
//  PopNetworking
//
//  Created by Daniel Koza on 1/8/21.
//  Copyright © 2021 Daniel Koza. All rights reserved.
//

import Foundation

// MARK: - NetworkingSession

internal protocol NetworkingSessionDelegate: AnyObject {
    func retry<Route: NetworkingRoute>(_ routeDataTask: NetworkingSession.RouteDataTask<Route>) async throws -> Result<Route.ResponseSerializer.SerializedObject, Error>
}

public extension NetworkingSession {
    /// A singleton ``NetworkingSession`` object.
    ///
    /// For basic requests, the ``NetworkingSession`` class provides a shared singleton session object that gives you a reasonable default behavior for creating tasks. Note: the ``NetworkingSession/shared`` instance does not utilize a ``NetworkingRequestAdapter`` or ``NetworkingRequestRetrier``
    static let shared = NetworkingSession()
}

/// Is  a wrapper class for `URLSession`. This class takes a ``NetworkingRoute`` and kicks off the HTTP request.
public class NetworkingSession {

    private let urlSession: URLSessionProtocol
    private let requestAdapter: NetworkingRequestAdapter?
    private let requestRetrier: NetworkingRequestRetrier?

    /// Creates an instance of a ``NetworkingSession``
    /// - Parameters:
    ///   - session: The underlying `URLSession` used to make an HTTP request. By default, a `URLSession` is configured with the `.default` `URLSessionConfiguration`
    ///   - requestAdapter: Responsible to modifying a `URLRequest` before being executed. See ``NetworkingRequestAdapter``
    ///   - requestRetrier: Responsible for retrying a failed `URLRequest`. See ``NetworkingRequestRetrier``
    public init(urlSession: URLSessionProtocol = URLSession(configuration: .default),
                requestAdapter: NetworkingRequestAdapter? = nil,
                requestRetrier: NetworkingRequestRetrier? = nil) {
        self.urlSession = urlSession
        self.requestAdapter = requestAdapter
        self.requestRetrier = requestRetrier
    }

    /// Creates an instance of a ``NetworkingSession`` with an instance of a ``ReauthenticationHandler``
    /// - Parameters:
    ///   - session: The underlying `URLSession` used to make an HTTP request. By default, a `URLSession` is configured with the `.default` `URLSessionConfiguration`
    ///   - accessTokenVerifier: See ``AccessTokenVerification``
    ///
    /// - Note: Pass in an ``AccessTokenVerification`` if you want to automatically reauthenticate network requests when your access token is expired.
    public init<AccessTokenVerifier: AccessTokenVerification>(urlSession: URLSessionProtocol = URLSession(configuration: .default),
                                                              reauthenticationHandler: ReauthenticationHandler<AccessTokenVerifier>) {
        self.urlSession = urlSession
        self.requestAdapter = reauthenticationHandler
        self.requestRetrier = reauthenticationHandler
    }

    /// Creates an instance of a ``NetworkingSession`` with an instance of an ``Interceptor``
    /// - Parameters:
    ///   - session: The underlying `URLSession` used to make an HTTP request. By default, a `URLSession` is configured with the `.default` `URLSessionConfiguration`
    ///   - interceptor: See ``Interceptor``
    public init(urlSession: URLSessionProtocol = URLSession(configuration: .default),
                interceptor: Interceptor) {
        self.urlSession = urlSession
        self.requestAdapter = interceptor
        self.requestRetrier = interceptor
    }

    /// Performs an HTTP request and parses the HTTP response into a `Task<Route.ResponseSerializer.SerializedObject, Error>`
    /// - Parameters:
    ///     - route: The ``NetworkingRoute`` you want to execute.
    /// - Returns: A `Task` that will return the `Route.ResponseSerializer.SerializedObject` or an `Error`. A `Task` can be cancelled.
    public func execute<Route: NetworkingRoute>(route: Route) -> Task<Route.ResponseSerializer.SerializedObject, Error> {
        Task {
            if let mockResponse = route.mockResponse {
                return try mockResponse.get()
            }
            else {
                let routeDataTask = RouteDataTask(route: route,
                                                  networkingSessionDelegate: self)
                return try await execute(routeDataTask).get()
            }
        }
    }

    private func execute<Route: NetworkingRoute>(_ routeDataTask: RouteDataTask<Route>) async throws -> Result<Route.ResponseSerializer.SerializedObject, Error> {
        let (request, responseData, response, error) = await routeDataTask.executeRoute(urlSession: urlSession,
                                                                                        requestAdapter: requestAdapter)

        var result = routeDataTask.executeResponseSerializer(responseData: responseData,
                                                             response: response,
                                                             responseError: error)

        result = try await routeDataTask.executeSessionRetrier(retrier: requestRetrier,
                                                               serializedResult: result,
                                                               request: request,
                                                               response: response,
                                                               responseError: error)

        result = try await routeDataTask.executeRouteRetrier(serializedResult: result,
                                                             response: response)
        return result
    }
}

extension NetworkingSession: NetworkingSessionDelegate {
    func retry<Route: NetworkingRoute>(_ routeDataTask: RouteDataTask<Route>) async throws -> Result<Route.ResponseSerializer.SerializedObject, Error> {
        return try await execute(routeDataTask)
    }
}
