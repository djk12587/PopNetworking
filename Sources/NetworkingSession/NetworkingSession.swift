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
    /// The ``NetworkingSession`` class provides a shared singleton session object that utilizes `URLSession` with a `URLSessionConfiguration.default` configuration.
    static let shared = NetworkingSession()
}

/// Is  a wrapper class for `URLSession`. This class takes a ``NetworkingRoute`` and kicks off the HTTP request.
public final class NetworkingSession: Sendable {

    private let urlSession: URLSessionProtocol
    private let requestAdapter: NetworkingRouteAdapter?
    private let requestRetrier: NetworkingRouteRetrier?

    public init(urlSession: URLSession = URLSession(configuration: .default),
                requestAdapter: NetworkingRouteAdapter? = nil,
                requestRetrier: NetworkingRouteRetrier? = nil) {
        self.urlSession = urlSession
        self.requestAdapter = requestAdapter
        self.requestRetrier = requestRetrier
    }

    public init(urlSession: URLSession = URLSession(configuration: .default),
                requestInterceptor: NetworkingRouteInterceptor? = nil) {
        self.urlSession = urlSession
        self.requestAdapter = requestInterceptor
        self.requestRetrier = requestInterceptor
    }

    public init(urlSession: URLSessionProtocol = URLSession(configuration: .default),
                requestAdapter: NetworkingRouteAdapter? = nil,
                requestRetrier: NetworkingRouteRetrier? = nil) {
        self.urlSession = urlSession
        self.requestAdapter = requestAdapter
        self.requestRetrier = requestRetrier
    }

    /// Performs an HTTP request and parses the HTTP response into the `Route.ResponseSerializer.SerializedObject`
    /// - Parameters:
    ///     - route: The ``NetworkingRoute`` you want to execute.
    /// - Returns: The `Route.ResponseSerializer.SerializedObject` or throws an `Error`.
    public func execute<Route: NetworkingRoute>(route: Route) async throws -> Route.ResponseSerializer.SerializedObject {
        return try await self.start(RouteDataTask(route: route, delegate: self)).get()
    }
}

extension NetworkingSession: RouteDataTaskDelegate {

    func retry<Route: NetworkingRoute>(_ routeDataTask: RouteDataTask<Route>, delay: TimeInterval?) async -> Result<Route.ResponseSerializer.SerializedObject, Error> {
        if let delay = delay {
            try? await Task.sleep(nanoseconds: UInt64(delay) * 1_000_000_000)
        }
        return await self.start(routeDataTask)
    }
}

private extension NetworkingSession {

    func start<Route: NetworkingRoute>(_ routeDataTask: RouteDataTask<Route>) async -> Result<Route.ResponseSerializer.SerializedObject, Error> {
        let urlRequestResult = await routeDataTask.buildURLRequest(adapter: self.requestAdapter)

        var (serializedResult, urlResponse) = await routeDataTask.start(urlRequestResult: urlRequestResult, on: self.urlSession)

        serializedResult = await routeDataTask.executeRetrier(retrier: self.requestRetrier,
                                                              serializedResult: serializedResult,
                                                              urlRequest: try? urlRequestResult.get(),
                                                              response: urlResponse)

        serializedResult = await routeDataTask.executeRepeater(serializedResult: serializedResult,
                                                               response: urlResponse)
        return serializedResult
    }
}
