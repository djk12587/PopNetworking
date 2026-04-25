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
/// * builds the `URLRequest` - (``NetworkingRoute/urlRequest``)
/// * adapts the `URLRequest` - (``NetworkingRoute/adapter``)
/// * executes the REST request with ``NetworkingSession/urlSession``
/// * validates the REST response - (``NetworkingRoute/responseValidator``)
/// * serializes the REST response into the ``NetworkingResponseSerializer/SerializedObject`` - (``NetworkingRoute/responseSerializer``)
/// * if an error occurred, retries the request - (``NetworkingRoute/retrier``)
/// * repeats the ``NetworkingRoute`` if needed - (``NetworkingRoute/repeater``)
/// * returns the ``NetworkingRoute``'s ``NetworkingResponseSerializer/SerializedObject`` or an `Error`
public final class NetworkingSession: NetworkingSessionProtocol {

    public var urlSession: URLSession { self._urlSession.session }

    private let _urlSession: URLSessionProtocol
    private let adapter: NetworkingAdapter?
    private let retrier: NetworkingRetrier?

    /// Creates an instance of a ``NetworkingSession``.
    /// - Parameters:
    ///   - urlSession: The ``URLSessionProtocol`` that executes the HTTP requests. `URLSession` conforms to ``URLSessionProtocol``.
    ///   - adapter: The ``NetworkingAdapter`` that runs for every ``NetworkingRoute``
    ///   - retrier: The ``NetworkingRetrier`` that runs for every ``NetworkingRoute``
    public init(urlSession: URLSessionProtocol = URLSession(configuration: .default),
                adapter: NetworkingAdapter? = nil,
                retrier: NetworkingRetrier? = nil) {
        self.adapter = adapter
        self.retrier = retrier
        self._urlSession = urlSession
    }

    /// Creates an instance of a ``NetworkingSession`` with a shared ``NetworkingInterceptor``.
    /// - Parameters:
    ///   - urlSession: The ``URLSessionProtocol`` that executes the HTTP requests. `URLSession` conforms to ``URLSessionProtocol``.
    ///   - interceptor: The ``NetworkingInterceptor`` that runs for every ``NetworkingRoute``
    public init(urlSession: URLSessionProtocol = URLSession(configuration: .default),
                interceptor: NetworkingInterceptor?) {
        self.adapter = interceptor
        self.retrier = interceptor
        self._urlSession = urlSession
    }

    /// Performs an HTTP request and parses the HTTP response into the `Route.ResponseSerializer.SerializedObject`
    /// - Parameters:
    ///     - route: The ``NetworkingRoute`` you want to execute.
    /// - Returns: The `Route.ResponseSerializer.SerializedObject` or throws an `Error`.
    public func execute<Route: NetworkingRoute>(route: Route) async throws -> Route.ResponseSerializer.SerializedObject {
        return try await self.start(RouteDataTask(route: route)).get()
    }
}

private extension NetworkingSession {

    /// Top-level iterative driver. Runs one attempt (adapters + request + retriers) to a terminal
    /// `(result, urlRequest, urlResponse)`, evaluates the repeater against that terminal state, and
    /// either returns or loops for another full attempt.
    func start<Route: NetworkingRoute>(_ routeDataTask: RouteDataTask<Route>) async -> Result<Route.ResponseSerializer.SerializedObject, Error> {
        while true {
            let response = await self.run(routeDataTask)

            switch await routeDataTask.executeRepeater(serializedResult: response.result,
                                                       urlRequest: response.urlRequest,
                                                       urlResponse: response.urlResponse) {
                case .doNotRetry:
                    return response.result
                case .retry:
                    continue
                case .retryWithDelay(let delay):
                    do {
                        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    } catch {
                        return .failure(URLError(.cancelled))
                    }
                    continue
            }
        }
    }

    /// Inner iterative loop: adapt the request, run it, ask the retriers what to do. Returns the
    /// terminal `(result, urlRequest, urlResponse)` for this attempt once the retriers return
    /// `.doNotRetry` (either because nothing failed, or because none of them want to retry).
    func run<Route: NetworkingRoute>(_ routeDataTask: RouteDataTask<Route>) async -> (result: Result<Route.ResponseSerializer.SerializedObject, Error>, urlRequest: URLRequest?, urlResponse: URLResponse?) {
        while true {
            var urlRequestResult = await routeDataTask.urlRequestResult

            for adapter in [self.adapter, routeDataTask.adapter, routeDataTask.interceptor].compactMap({ $0 }).sortedByPriority {
                urlRequestResult = await routeDataTask.executeAdapter(adapter, on: urlRequestResult)
            }

            let (serializedResult, urlResponse) = await routeDataTask.start(urlRequestResult: urlRequestResult, on: self._urlSession)

            let retriers = [self.retrier, routeDataTask.retrier, routeDataTask.interceptor].compactMap({ $0 }).sortedByPriority
            let retryDecision = await routeDataTask.executeRetrier(serializedResult: serializedResult,
                                                                   urlRequest: try? urlRequestResult.get(),
                                                                   urlResponse: urlResponse,
                                                                   retriers: retriers)

            switch retryDecision {
                case .doNotRetry:
                    return (serializedResult, try? urlRequestResult.get(), urlResponse)
                case .retry:
                    continue
                case .retryWithDelay(let delay):
                    do {
                        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    } catch {
                        return (.failure(URLError(.cancelled)), try? urlRequestResult.get(), urlResponse)
                    }
                    continue
            }
        }
    }
}
