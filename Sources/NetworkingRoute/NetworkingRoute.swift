//
//  NetworkRoute.swift
//  PopNetworking
//
//  Created by Daniel Koza on 1/7/21.
//  Copyright © 2021 Daniel Koza. All rights reserved.
//

import Foundation

/// ``NetworkingRoute`` is responsible for declaring everything needed to create a networking request and outlines how to parse the networking response into a custom object.
public protocol NetworkingRoute: Sendable {

    typealias NetworkingRouteHttpHeaders = [String : String]

    /// `ResponseSerializer` allows for plug and play networking response serialization.
    ///
    /// For examples of prebuilt `NetworkingResponseSerializer`'s see ``NetworkingResponseSerializers``
    associatedtype ResponseSerializer: NetworkingResponseSerializer where ResponseSerializer.SerializedObject: Sendable

    /// The ``NetworkingSession`` used to execute the route
    var session: NetworkingSession { get }

    /// Declares the base URL
    var baseUrl: String { get }
    /// Declares the path of the url
    var path: String { get }
    /// Declares the HTTP method
    var method: NetworkingRouteHttpMethod { get }
    /// Declares the request headers
    var headers: NetworkingRouteHttpHeaders? { get }

    /// <doc:/documentation/PopNetworking/NetworkingRoute/parameterEncoding-5o5po> is responsible for encoding all of your network request's parameters into a `URLRequest`.
    var parameterEncoding: NetworkingRequestParameterEncoding? { get }

    /// ``urlRequest-793sf`` is responsible for creating the `URLRequest` that will be ran on an instance of `URLSession`.
    var urlRequest: URLRequest { get throws }

    /// When not nil, the route will not run on URLSession and the responseValidator will not be invoked.
    var mockSerializedResult: Result<ResponseSerializer.SerializedObject, Error>? { get async }

    /// A `responseValidator` allows you to inspect the raw networking data and URLResponse.
    var responseValidator: NetworkingResponseValidator? { get }

    /// A `ResponseSerializer` is responsible for parsing the raw response of an HTTP request into a more usable object, like a Model object. The `ResponseSerializer` must adhere to ``NetworkingResponseSerializer``
    ///
    /// Prebuilt `ResponseSerializer`s can be found here: ``NetworkingResponseSerializers``.
    var responseSerializer: ResponseSerializer { get }

    /// A `Repeater` allows you to retry the entire request if needed. This can be used if you have to repeatedly poll an endpoint to wait for a specific status to be returned.
    ///
    /// ```swift
    /// // example usage
    /// let response = try await SomeNetworkingRoute(repeater: { result, response, repeatCount in
    ///     if repeatCount < 2 && response?.statusCode == 500 {
    ///         return .retryWithDelay(1) // repeats the request if the server returns a 500
    ///     } else {
    ///         return .doNotRetry
    ///     }
    /// }).run
    /// ```
    var repeater: Repeater? { get }

    /// <doc:/documentation/PopNetworking/NetworkingRoute/urlRequest-5u991>'s default implementation will use <doc:/documentation/PopNetworking/NetworkingRoute/timeoutInterval-9db54> when instantiating a `URLRequest(url: timeoutInterval:)`.
    ///
    /// - Note: If nil, the default, 60 seconds is used.
    var timeoutInterval: TimeInterval? { get }

}

public extension NetworkingRoute {

    /// Default implementation provided. Feel free to implement your own version if needed.
    var urlRequest: URLRequest {
        get throws {
            guard let url = URL(string: self.baseUrl.appending(self.path)) else {
                throw URLError(.badURL, userInfo: ["baseUrl": self.baseUrl, "path": self.path])
            }

            var mutableRequest = URLRequest(url: url, timeoutInterval: self.timeoutInterval ?? 60.0)
            mutableRequest.httpMethod = self.method.rawValue
            try self.parameterEncoding?.encodeParams(into: &mutableRequest)
            self.headers?.forEach { mutableRequest.addValue($0.value, forHTTPHeaderField: $0.key) }
            return mutableRequest
        }
    }

    /// Runs the `NetworkingRoute`
    ///
    /// Default implementation provided. Feel free to implement your own version if needed.
    /// - Returns: a serialized object
    var run: ResponseSerializer.SerializedObject {
        get async throws {
            try await self.session.execute(route: self)
        }
    }

    /// Runs the `NetworkingRoute`
    ///
    /// Default implementation provided. Feel free to implement your own version if needed.
    ///
    /// ```swift
    /// extension NetworkingRoute {
    ///
    ///     func task(priority: TaskPriority? = nil) -> Task<ResponseSerializer.SerializedObject, Error> {
    ///         Task(priority: priority) {
    ///             try await self.run
    ///         }
    ///     }
    /// }
    /// ```
    /// - Returns: A Task that contains your serialized object
    func task(priority: TaskPriority? = nil) -> Task<ResponseSerializer.SerializedObject, Error> {
        Task(priority: priority) {
            try await self.run
        }
    }

    /// Runs the `NetworkingRoute`
    ///
    /// Default implementation provided. Feel free to implement your own version if needed.
    ///
    /// ```swift
    /// extension NetworkingRoute {
    ///
    ///     var result: Result<ResponseSerializer.SerializedObject, Error> {
    ///         get async {
    ///             await Result { try await self.run }
    ///         }
    ///     }
    /// }
    /// ```
    /// - Returns: A Result type that contains a serialized object
    var result: Result<ResponseSerializer.SerializedObject, Error> {
        get async {
            await Result { try await self.run }
        }
    }

    /// Runs the `NetworkingRoute`
    ///
    /// Default implementation provided. Feel free to implement your own version if needed.
    ///
    /// - Parameters:
    ///   - priority: Sets a `TaskPriority` for your request. Defaults to nil
    ///   - queue: The queue your `completion` will be executed on. The default is the main thread.
    ///   - completion: Provides you with a serialized object or error
    @discardableResult
    func request(priority: TaskPriority? = nil,
                 completeOn queue: DispatchQueue = .main,
                 completion: (@Sendable (Result<ResponseSerializer.SerializedObject, Error>) -> Void)?) -> Task<ResponseSerializer.SerializedObject, Error> {
        let requestTask = self.task(priority: priority)
        Task(priority: priority) {
            let result = await requestTask.result
            queue.async { completion?(result) }
        }
        return requestTask
    }

    var session: NetworkingSession { .shared }
    var headers: NetworkingRouteHttpHeaders? { nil }
    var parameterEncoding: NetworkingRequestParameterEncoding? { nil }
    var timeoutInterval: TimeInterval? { nil }
    var mockSerializedResult: Result<ResponseSerializer.SerializedObject, Error>? { nil }
    var responseValidator: NetworkingResponseValidator? { nil }
    var repeater: Repeater? { nil }
}

public extension NetworkingRoute {
    typealias Repeater = @Sendable (_ result: Result<ResponseSerializer.SerializedObject, Error>,
                                    _ response: URLResponse?,
                                    _ repeatCount: Int) async -> NetworkingRouteRetrierResult
}
