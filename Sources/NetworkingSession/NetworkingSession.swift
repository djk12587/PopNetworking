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

    func retry<Route: NetworkingRoute>(_ routeDataTask: NetworkingSession.RouteDataTask<Route>,
                                       delay: TimeInterval?) async throws -> Result<Route.ResponseSerializer.SerializedObject, Error>
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

    public init(urlSession: URLSessionProtocol = URLSession(configuration: .default),
                requestAdapter: NetworkingRequestAdapter? = nil,
                requestRetrier: NetworkingRequestRetrier? = nil) {
        self.urlSession = urlSession
        self.requestAdapter = requestAdapter
        self.requestRetrier = requestRetrier
    }

    public init(urlSession: URLSessionProtocol = URLSession(configuration: .default),
                requestInterceptor: NetworkingRequestInterceptor? = nil) {
        self.urlSession = urlSession
        self.requestAdapter = requestInterceptor
        self.requestRetrier = requestInterceptor
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

    func retry<Route: NetworkingRoute>(_ routeDataTask: RouteDataTask<Route>, delay: TimeInterval?) async throws -> Result<Route.ResponseSerializer.SerializedObject, Error> {
        guard let delay = delay else { return try await execute(routeDataTask) }
        try? await Task.sleep(nanoseconds: UInt64(delay) * 1_000_000_000)
        return try await execute(routeDataTask)
    }
}

private extension NetworkingSession {

    func execute<Route: NetworkingRoute>(_ routeDataTask: RouteDataTask<Route>) async throws -> Result<Route.ResponseSerializer.SerializedObject, Error> {
        let (request, response, result) = await routeDataTask.executeRoute(urlSession: urlSession,
                                                                           requestAdapter: requestAdapter)

        try checkForCancellation(routeType: Route.self,
                                 rawPayload: (request, response, result))

        var serializedResult = await routeDataTask.executeResponseSerializer(result: result,
                                                                             response: response)
        
        serializedResult = try await routeDataTask.executeSessionRetrier(retrier: requestRetrier,
                                                                         serializedResult: serializedResult,
                                                                         request: request,
                                                                         response: response,
                                                                         responseError: result.error)

        try checkForCancellation(routeType: Route.self,
                                 rawPayload: (request, response, result),
                                 result: serializedResult)

        serializedResult = try await routeDataTask.executeRouteRetrier(serializedResult: serializedResult,
                                                                       response: response)

        try checkForCancellation(routeType: Route.self,
                                 rawPayload: (request, response, result),
                                 result: serializedResult)

        return serializedResult
    }

    func checkForCancellation<Route: NetworkingRoute>(routeType: Route.Type,
                                                      rawPayload: RouteDataTask.RawRequestResponse,
                                                      result: Result<Route.ResponseSerializer.SerializedObject, Error>? = nil) throws {
        guard Task.isCancelled else { return }
        throw URLError(.cancelled, userInfo: ["Reason": "\(routeType.self) was cancelled.",
                                              "RawPayload": (rawPayload.request, rawPayload.response, rawPayload.result),
                                              "Result": result].compactMapValues({ $0 }))
    }
}
