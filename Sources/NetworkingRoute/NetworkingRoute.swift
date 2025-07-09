//
//  NetworkRoute.swift
//  PopNetworking
//
//  Created by Daniel Koza on 1/7/21.
//  Copyright © 2021 Daniel Koza. All rights reserved.
//

import Foundation

/// ``NetworkingRoute`` is responsible for declaring everything needed to create a networking request and how to parse the networking response into a generic ``NetworkingResponseSerializer/SerializedObject`` object.
public protocol NetworkingRoute: Sendable {

    typealias NetworkingRouteHttpHeaders = [String : String]

    /// `ResponseSerializer` allows for plug and play networking response serialization.
    ///
    /// For examples of prebuilt `NetworkingResponseSerializer`'s see ``NetworkingResponseSerializers``
    associatedtype ResponseSerializer: NetworkingResponseSerializer

    /// The ``NetworkingSessionProtocol`` is used to execute the route and return the serialized object.
    ///
    /// ``NetworkingSession`` is the a default implementation of ``NetworkingSessionProtocol``.
    var session: NetworkingSessionProtocol { get async }

    /// Declares the base URL
    var baseUrl: String { get async }
    /// Declares the path of the url
    var path: String { get async }
    /// Declares the HTTP method
    var method: NetworkingRouteHttpMethod { get async }
    /// Declares the request headers
    var headers: NetworkingRouteHttpHeaders? { get async }

    /// ``NetworkingRoute/parameterEncoding-16vgm`` is responsible for encoding all of your network request's parameters into a `URLRequest`.
    var parameterEncoding: NetworkingRouteParameterEncoding? { get async }

    /// ``urlRequest-793sf`` is responsible for creating the `URLRequest` that will be ran on an instance of `URLSession`.
    var urlRequest: URLRequest { get async throws }

    /// ``NetworkingAdapter`` tied to the ``NetworkingRoute``.
    ///
    /// If ``NetworkingSession`` & ``NetworkingRoute`` have ``NetworkingAdapter``'s with the same ``NetworkingPriority``, the adapter tied to the ``NetworkingSession`` is ran first.
    var adapter: NetworkingAdapter? { get }

    /// Used for testing, a <doc:/documentation/PopNetworking/NetworkingRoute/mockSerializedResult-96yhb> skips ``URLSessionProtocol/data(for:)``, <doc:/documentation/PopNetworking/NetworkingRoute/responseValidator-2fydu>, and ``NetworkingResponseSerializer/serialize(responseResult:)``.
    var mockSerializedResult: Result<ResponseSerializer.SerializedObject, Error>? { get async }

    /// A `responseValidator` allows you to inspect the raw networking data and URLResponse.
    var responseValidator: NetworkingResponseValidator? { get }

    /// A `ResponseSerializer` is responsible for parsing the raw response of an HTTP request into a more usable object, like a Model object. The `ResponseSerializer` must adhere to ``NetworkingResponseSerializer``
    ///
    /// Prebuilt `ResponseSerializer`s can be found here: ``NetworkingResponseSerializers``.
    var responseSerializer: ResponseSerializer { get }

    /// ``NetworkingRetrier`` tied to the ``NetworkingRoute``.
    ///
    /// If ``NetworkingSession`` & ``NetworkingRoute`` have ``NetworkingRetrier``'s with the same ``NetworkingPriority``, the retrier tied to the ``NetworkingSession`` is ran first.
    var retrier: NetworkingRetrier? { get }

    /// ``NetworkingInterceptor`` tied to the ``NetworkingRoute``.
    ///
    /// If ``NetworkingSession`` & ``NetworkingRoute`` have ``NetworkingInterceptor``'s with the same ``NetworkingPriority``, the interceptor tied to the ``NetworkingSession`` is ran first. Additionally, assuming the same ``NetworkingPriority``, ``NetworkingAdapter``'s & ``NetworkingRetrier``'s will be ran before ``NetworkingInterceptor``'s.
    var interceptor: NetworkingInterceptor? { get }

    /// A `Repeater` allows you to retry the entire request if needed. This can be used if you have to repeatedly poll an endpoint to wait for a specific status to be returned.
    ///
    /// ```swift
    /// // example usage
    /// let response = try await SomeNetworkingRoute(repeater: { (result, request, response, repeatCount) in
    ///     if repeatCount < 2 && (response as? HTTPURLResponse)?.statusCode == 500 {
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
        get async throws {
            guard let url = await URL(string: self.baseUrl.appending(self.path)) else {
                throw await URLError(.badURL, userInfo: ["baseUrl": self.baseUrl, "path": self.path])
            }

            var mutableRequest = URLRequest(url: url, timeoutInterval: self.timeoutInterval ?? 60.0)
            mutableRequest.httpMethod = await self.method.rawValue
            try await self.parameterEncoding?.encodeParams(into: &mutableRequest)
            await self.headers?.forEach { mutableRequest.addValue($0.value, forHTTPHeaderField: $0.key) }
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

    var session: NetworkingSessionProtocol { NetworkingSession.shared }
    var headers: NetworkingRouteHttpHeaders? { nil }
    var parameterEncoding: NetworkingRouteParameterEncoding? { nil }
    var timeoutInterval: TimeInterval? { nil }
    var adapter: NetworkingAdapter? { nil }
    var mockSerializedResult: Result<ResponseSerializer.SerializedObject, Error>? { nil }
    var responseValidator: NetworkingResponseValidator? { nil }
    var retrier: NetworkingRetrier? { nil }
    var interceptor: NetworkingInterceptor? { nil }
    var repeater: Repeater? { nil }
}

public extension NetworkingRoute {
    typealias Repeater = @Sendable (_ result: Result<ResponseSerializer.SerializedObject, Error>,
                                    _ urlRequest: URLRequest?,
                                    _ response: URLResponse?,
                                    _ repeatCount: Int) async -> NetworkingRetrierResult
}
