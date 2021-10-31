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
                return try await execute(RouteDataTask(route: route,
                                                       requestAdapter: requestAdapter,
                                                       requestRetrier: requestRetrier,
                                                       routeDataTaskDelegate: self)).get()
            }
        }
    }

    private func execute<Route: NetworkingRoute>(_ routeDataTask: RouteDataTask<Route>) async -> Result<Route.ResponseSerializer.SerializedObject, Error> {
        do {
            let urlRequest = try routeDataTask.urlRequest
            let responseTask = session.createAsyncTask(for: urlRequest)

            do { try Task.checkCancellation() }
            catch {
                responseTask.cancel()
            }

            let (responseData, response, responseError) = await responseTask.value
            return await routeDataTask.executeResponseSerializer(with: URLSessionDataTask.RawResponse(urlRequest: urlRequest,
                                                                                                      urlResponse: response as? HTTPURLResponse,
                                                                                                      data: responseData,
                                                                                                      error: responseError))
        } catch {
            return await routeDataTask.executeResponseSerializer(with: URLSessionDataTask.RawResponse(urlRequest: nil,
                                                                                                      urlResponse: nil,
                                                                                                      data: nil,
                                                                                                      error: error))
        }
    }
}

extension NetworkingSession: NetworkingRouteDataTaskDelegate {
    internal func retry<Route: NetworkingRoute>(routeDataTask: RouteDataTask<Route>) async -> Result<Route.ResponseSerializer.SerializedObject, Error> {
        await execute(routeDataTask)
    }
}

private extension URLSession {
    func createAsyncTask(for urlRequest: URLRequest) -> Task<(Data?, URLResponse?, Error?), Never> {
        return Task {
            await withCheckedContinuation { continuation in
                let urlSessionDataTask = dataTask(with: urlRequest) { (responseData, response, error) in
                    continuation.resume(returning: (responseData, response, error))
                }
                urlSessionDataTask.resume()

                do { try Task.checkCancellation() }
                catch {
                    urlSessionDataTask.cancel()
                }
            }
        }
    }
}
