//
//  Networking+Session.swift
//  PopNetworking
//
//  Created by Daniel Koza on 1/8/21.
//  Copyright © 2021 Daniel Koza. All rights reserved.
//

import Foundation

/// `NetworkingSessionProtocol` is responsible for executing an instance of ``NetworkingRoute`` and returning the route's ``NetworkingResponseSerializer/SerializedObject``
public protocol NetworkingSessionProtocol: Sendable {

    var urlSession: URLSession { get }
    func execute<Route: NetworkingRoute>(route: Route) async throws -> Route.ResponseSerializer.SerializedObject

}

public extension NetworkingSession {
    /// A singleton ``NetworkingSession`` object.
    ///
    /// The ``NetworkingSession`` class provides a shared singleton session object that utilizes `URLSession` with a `URLSessionConfiguration.default` configuration.
    static let shared = NetworkingSession()
}

/// ``NetworkingSession`` is a wrapper class for `URLSession`. Conforms to ``NetworkingSessionProtocol``
///
/// When ``NetworkingSession/execute(route:)`` is called, the following actions are performed on an instance of ``NetworkingRoute``
/// * builds the `URLRequest` - (``NetworkingRoute``.``NetworkingRoute/urlRequest-5u991``)
/// * adapts the `URLRequest` - (``NetworkingRoute``.``NetworkingRoute/adapter-1x7eb``)
/// * executes the REST request with ``NetworkingSession/urlSession``
/// * validates the REST response - (``NetworkingRoute``.``NetworkingRoute/responseValidator-220e4``)
/// * serializes the REST response into the ``NetworkingResponseSerializer/SerializedObject`` - (``NetworkingRoute``.``NetworkingRoute/responseSerializer``)
/// * if an error occurred error, retry the request - (``NetworkingRoute``.``NetworkingRoute/adapter-8np6``
/// * repeats the ``NetworkingRoute`` if needed - (``NetworkingRoute``.``NetworkingRoute/repeater-397rr``)
/// * returns the ``NetworkingRoute``'s ``NetworkingResponseSerializer/SerializedObject`` or an `Error`
public final class NetworkingSession: NetworkingSessionProtocol {

    public var urlSession: URLSession { self._urlSession.session }

    private let _urlSession: URLSessionProtocol
    private let adapter: NetworkingAdapter?
    private let retrier: NetworkingRetrier?
    
    /// Creates an instance of a ``NetworkingSession`` with a `URLSession`.
    /// - Parameters:
    ///   - urlSession: The `URLSession` that executes the HTTP requests.
    ///   - adapter: The ``NetworkingAdapter`` that is ran for every ``NetworkingRoute``
    ///   - retrier: The ``NetworkingRetrier`` that is ran for every ``NetworkingRoute``
    public init(urlSession: URLSession = URLSession(configuration: .default),
                adapter: NetworkingAdapter? = nil,
                retrier: NetworkingRetrier? = nil) {
        self.adapter = adapter
        self.retrier = retrier
        self._urlSession = urlSession
    }

    /// Creates an instance of a ``NetworkingSession`` with a `URLSession`.
    /// - Parameters:
    ///   - urlSession: The `URLSession` that executes the HTTP requests.
    ///   - interceptor: The ``NetworkingInterceptor`` that is ran for every ``NetworkingRoute``
    public init(urlSession: URLSession = URLSession(configuration: .default),
                interceptor: NetworkingInterceptor? = nil) {
        self.adapter = interceptor
        self.retrier = interceptor
        self._urlSession = urlSession
    }

    /// Creates an instance of a ``NetworkingSession`` with a ``URLSessionProtocol``.
    /// - Parameters:
    ///   - urlSession: The ``URLSessionProtocol`` that executes the HTTP requests.
    ///   - adapter: The ``NetworkingAdapter`` that is ran for every ``NetworkingRoute``
    ///   - retrier: The ``NetworkingRetrier`` that is ran for every ``NetworkingRoute``
    public init(urlSession: URLSessionProtocol,
                adapter: NetworkingAdapter? = nil,
                retrier: NetworkingRetrier? = nil) {
        self.adapter = adapter
        self.retrier = retrier
        self._urlSession = urlSession
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
        var urlRequestResult = await routeDataTask.urlRequestResult

        for adapter in [self.adapter, routeDataTask.adapter, routeDataTask.interceptor].compactMap({ $0 }).sortedByPriority {
            urlRequestResult = await routeDataTask.execute(adapter: adapter, on: urlRequestResult)
        }

        var (serializedResult, urlResponse) = await routeDataTask.start(urlRequestResult: urlRequestResult, on: self._urlSession)

        for retrier in [self.retrier, routeDataTask.retrier, routeDataTask.interceptor].compactMap({ $0 }).sortedByPriority {
            serializedResult = await routeDataTask.execute(retrier: retrier,
                                                           serializedResult: serializedResult,
                                                           urlRequest: try? urlRequestResult.get(),
                                                           urlResponse: urlResponse)
        }

        serializedResult = await routeDataTask.executeRepeater(serializedResult: serializedResult,
                                                               urlRequest: try? urlRequestResult.get(),
                                                               urlResponse: urlResponse)

        return serializedResult
    }
}
