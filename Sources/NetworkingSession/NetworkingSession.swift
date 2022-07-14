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

    public init(urlSession: URLSessionProtocol = URLSession(configuration: .default),
                interceptor: Interceptor? = nil,
                requestAdapter: NetworkingRequestAdapter? = nil,
                requestRetrier: NetworkingRequestRetrier? = nil,
                requestIntercepter: NetworkingRequestInterceptor? = nil) {

        var adapters: [NetworkingRequestAdapter?] = []
        adapters.append(requestAdapter)
        adapters.append(requestIntercepter)
        adapters.append(contentsOf: interceptor?.adapters ?? [])

        var retriers: [NetworkingRequestRetrier?] = []
        retriers.append(requestRetrier)
        retriers.append(requestIntercepter)
        retriers.append(contentsOf: interceptor?.retriers ?? [])

        let allAdaptersAndRetriers = Interceptor(adapters: adapters.compactMap({ $0 }),
                                                 retriers: retriers.compactMap({ $0 }))
        self.requestAdapter = allAdaptersAndRetriers
        self.requestRetrier = allAdaptersAndRetriers
        self.urlSession = urlSession
    }

    public convenience init(urlSession: URLSessionProtocol = URLSession(configuration: .default),
                            interceptor: Interceptor? = nil,
                            requestAdapter: NetworkingRequestAdapter? = nil,
                            requestRetrier: NetworkingRequestRetrier? = nil,
                            requestIntercepter: NetworkingRequestInterceptor? = nil,
                            accessTokenVerifier: some AccessTokenVerification) {

        let reauthenticationHandler = ReauthenticationHandler(accessTokenVerifier: accessTokenVerifier)
        let combinedInterceptor = Interceptor(adapters: [reauthenticationHandler] + (interceptor?.adapters ?? []),
                                              retriers: [reauthenticationHandler] + (interceptor?.retriers ?? []))
        self.init(urlSession: urlSession,
                  interceptor: combinedInterceptor,
                  requestAdapter: requestAdapter,
                  requestRetrier: requestRetrier,
                  requestIntercepter: requestIntercepter)
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
