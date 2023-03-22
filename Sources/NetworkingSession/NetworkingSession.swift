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
                                       delay: TimeInterval?) async -> Result<Route.ResponseSerializer.SerializedObject, Error>
    func reconnect<Route: NetworkingRoute>(to routeWebSocketTask: NetworkingSession.RouteWebSocketTask<Route>,
                                           streamContinuation: AsyncStream<Route.StreamResponse>.Continuation,
                                           delay: TimeInterval?) async
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

    public init(urlSession: URLSession = URLSession(configuration: .default),
                requestAdapter: NetworkingRequestAdapter? = nil,
                requestRetrier: NetworkingRequestRetrier? = nil) {
        self.urlSession = urlSession
        self.requestAdapter = requestAdapter
        self.requestRetrier = requestRetrier
    }

    public init(urlSession: URLSession = URLSession(configuration: .default),
                requestInterceptor: NetworkingRequestInterceptor? = nil) {
        self.urlSession = urlSession
        self.requestAdapter = requestInterceptor
        self.requestRetrier = requestInterceptor
    }

    public init(urlSession: URLSessionProtocol = URLSession(configuration: .default),
                requestAdapter: NetworkingRequestAdapter? = nil,
                requestRetrier: NetworkingRequestRetrier? = nil) {
        self.urlSession = urlSession
        self.requestAdapter = requestAdapter
        self.requestRetrier = requestRetrier
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

    public func stream<Route: NetworkingRoute>(route: Route, streamContinuation: AsyncStream<Route.StreamResponse>.Continuation) async {
        if let mockResult = route.mockResponse {
            streamContinuation.yield((mockResult, nil))
            streamContinuation.finish()
        } else {
            let routeWebSocketTask = RouteWebSocketTask(route: route,
                                                        urlSessionConfiguration: urlSession.configuration,
                                                        networkingSessionDelegate: self)
            await stream(routeWebSocketTask, streamContinuation: streamContinuation)
        }
    }
}

extension NetworkingSession: NetworkingSessionDelegate {

    func retry<Route: NetworkingRoute>(_ routeDataTask: RouteDataTask<Route>, delay: TimeInterval?) async -> Result<Route.ResponseSerializer.SerializedObject, Error> {
        if let delay = delay {
            try? await Task.sleep(nanoseconds: UInt64(delay) * 1_000_000_000)
        }
        return await execute(routeDataTask)
    }

    func reconnect<Route: NetworkingRoute>(to routeWebSocketTask: RouteWebSocketTask<Route>, streamContinuation: AsyncStream<Route.StreamResponse>.Continuation, delay: TimeInterval?) async {
        if let delay = delay {
            try? await Task.sleep(nanoseconds: UInt64(delay) * 1_000_000_000)
        }
        await stream(routeWebSocketTask, streamContinuation: streamContinuation)
    }
}

private extension NetworkingSession {

    func execute<Route: NetworkingRoute>(_ routeDataTask: RouteDataTask<Route>) async -> Result<Route.ResponseSerializer.SerializedObject, Error> {
        let (responseDataResult, urlResponse, urlRequest) = await routeDataTask.execute(on: urlSession,
                                                                                        adapter: requestAdapter)

        let validatedResponseDataResult = await routeDataTask.executeResponseValidator(result: responseDataResult,
                                                                                       response: urlResponse)

        var serializedResult = await routeDataTask.executeResponseSerializer(result: validatedResponseDataResult,
                                                                             response: urlResponse)

        serializedResult = await routeDataTask.executeRetrier(retrier: requestRetrier,
                                                              serializedResult: serializedResult,
                                                              urlRequest: urlRequest,
                                                              response: urlResponse)

        serializedResult = await routeDataTask.executeRepeater(serializedResult: serializedResult,
                                                               response: urlResponse)

        return serializedResult
    }

    func stream<Route: NetworkingRoute>(_ routeWebSocketTask: RouteWebSocketTask<Route>, streamContinuation: AsyncStream<Route.StreamResponse>.Continuation) async {
        let (webSocketCreationResult, urlRequest) = await routeWebSocketTask.createWebSocketTask(adapter: requestAdapter)
        do {
            let webSocketUrlTask = try await routeWebSocketTask.open(webSocketCreationResult)
            try await routeWebSocketTask.startListening(to: webSocketUrlTask, streamContinuation: streamContinuation)
        }
        catch {
            await routeWebSocketTask.executeRetrier(retrier: requestRetrier,
                                                    error: error,
                                                    streamContinuation: streamContinuation,
                                                    urlRequest: urlRequest,
                                                    response: (try? webSocketCreationResult.get().0.response as? HTTPURLResponse))
        }
    }
}
