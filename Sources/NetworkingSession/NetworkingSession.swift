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

    /// Creates an instance of a ``NetworkingSession`` with an instance of an ``AccessTokenVerification``
    /// - Parameters:
    ///   - session: The underlying `URLSession` used to make an HTTP request. By default, a `URLSession` is configured with the `.default` `URLSessionConfiguration`
    ///   - accessTokenVerifier: See ``AccessTokenVerification``
    ///
    /// - Note: Pass in an ``AccessTokenVerification`` if you want to automatically reauthenticate network requests when your access token is expired.
    public init<AccessTokenVerifier: AccessTokenVerification>(urlSession: URLSessionProtocol = URLSession(configuration: .default),
                                                              accessTokenVerifier: AccessTokenVerifier) {
        self.urlSession = urlSession
        let reauthenticationHandler = ReauthenticationHandler(accessTokenVerifier: accessTokenVerifier)
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

    /// Performs an HTTP request and parses the HTTP response into the `Route.ResponseSerializer.SerializedObject`
    /// - Parameters:
    ///     - route: The ``NetworkingRoute`` you want to execute.
    /// - Returns: The `Route.ResponseSerializer.SerializedObject` or throws an `Error`.
    public func execute<Route: NetworkingRoute>(route: Route) async throws -> Route.ResponseSerializer.SerializedObject {
        if let mockResponse = route.mockResponse {
            return try mockResponse.get()
        }
        else {
            let routeDataTask = RouteDataTask(route: route, networkingSessionDelegate: self)
            return try await execute(routeDataTask).get()
        }
    }
}

extension NetworkingSession: NetworkingSessionDelegate {

    func retry<Route: NetworkingRoute>(_ routeDataTask: RouteDataTask<Route>) async throws -> Result<Route.ResponseSerializer.SerializedObject, Error> {
        return try await execute(routeDataTask)
    }
}

private extension NetworkingSession {

    func execute<Route: NetworkingRoute>(_ routeDataTask: RouteDataTask<Route>) async throws -> Result<Route.ResponseSerializer.SerializedObject, Error> {
        let (request, responseData, response, error) = await routeDataTask.executeRoute(urlSession: urlSession,
                                                                                        requestAdapter: requestAdapter)

        try checkForCancellation(routeType: Route.self,
                                 rawPayload: (request, responseData, response, error))

        var result = routeDataTask.executeResponseSerializer(responseData: responseData,
                                                             response: response,
                                                             responseError: error)

        result = try await routeDataTask.executeSessionRetrier(retrier: requestRetrier,
                                                               serializedResult: result,
                                                               request: request,
                                                               response: response,
                                                               responseError: error)

        try checkForCancellation(routeType: Route.self,
                                 rawPayload: (request, responseData, response, error),
                                 result: result)

        result = try await routeDataTask.executeRouteRetrier(serializedResult: result,
                                                             response: response)

        try checkForCancellation(routeType: Route.self,
                                 rawPayload: (request, responseData, response, error),
                                 result: result)

        return result
    }

    func checkForCancellation<Route: NetworkingRoute>(routeType: Route.Type,
                                                      rawPayload: (request: URLRequest?, responseData: Data?, response: HTTPURLResponse?, error: Error?),
                                                      result: Result<Route.ResponseSerializer.SerializedObject, Error>? = nil) throws {
        guard Task.isCancelled else { return }
        throw URLError(.cancelled, userInfo: ["Reason": "\(routeType.self) was cancelled.",
                                              "RawPayload": (rawPayload.request, rawPayload.responseData, rawPayload.response, rawPayload.error),
                                              "Result": result].compactMapValues({ $0 }))
    }
}
