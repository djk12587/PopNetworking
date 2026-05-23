//
//  NetworkRoute.swift
//  PopNetworking
//
//  Created by Daniel Koza on 1/7/21.
//  Copyright © 2021 Daniel Koza. All rights reserved.
//

import Foundation

/// ``NetworkingResponseRoute`` describes a response HTTP route: how to build the request (via
/// ``NetworkingEndpoint``), what hooks attach to it (via ``NetworkingHooks``), and how to
/// serialize / retry the response.
///
/// The request-construction surface (``NetworkingEndpoint/baseUrl``, ``NetworkingEndpoint/path``, etc.)
/// is inherited from ``NetworkingEndpoint``. The hook surface (``NetworkingHooks/adapter``,
/// ``NetworkingHooks/retrier``, ``NetworkingHooks/interceptor``, ``NetworkingHooks/observers``)
/// is inherited from ``NetworkingHooks``.
public protocol NetworkingResponseRoute: NetworkingEndpoint, NetworkingHooks {

    /// `Serializer` allows for plug and play networking response serialization.
    ///
    /// For examples of prebuilt `NetworkingResponseSerializer`'s see ``NetworkingSerializers``
    associatedtype Serializer: NetworkingResponseSerializer

    /// Used for testing. When set, the mock result is returned in place of a real network response.
    ///
    /// Runs: ``NetworkingAdapter``, ``NetworkingRetrier``, ``NetworkingInterceptor``, and ``Repeater``.
    ///
    /// Skips: ``URLSessionProtocol/data(for:)``, ``NetworkingResponseSerializer/serialize(responseResult:)``, and ``NetworkingTransportObserver`` notifications.
    var mockSerializedResult: Result<Serializer.SerializedObject, Error>? { get }

    /// A `Serializer` is responsible for parsing the raw response of an HTTP request into a more usable object, like a Model object. The `Serializer` must adhere to ``NetworkingResponseSerializer``
    ///
    /// Prebuilt `Serializer`s can be found here: ``NetworkingSerializers``.
    var serializer: Serializer { get }

    /// A `Repeater` allows you to retry the entire request if needed. This can be used if you have to repeatedly poll an endpoint to wait for a specific status to be returned.
    ///
    /// ```swift
    /// // example usage
    /// let response = try await SomeNetworkingResponseRoute(repeater: { (result, request, response, repeatCount) in
    ///     if repeatCount < 2 && (response as? HTTPURLResponse)?.statusCode == 500 {
    ///         return .retryWithDelay(1) // repeats the request if the server returns a 500
    ///     } else {
    ///         return .doNotRetry
    ///     }
    /// }).run
    /// ```
    var repeater: Repeater? { get }
}

public extension NetworkingResponseRoute {

    /// Runs the `NetworkingResponseRoute`
    ///
    /// Default implementation provided. Feel free to implement your own version if needed.
    /// - Returns: a serialized object
    var run: Serializer.SerializedObject {
        get async throws {
            try await self.session.execute(route: self)
        }
    }

    /// Runs the `NetworkingResponseRoute`
    ///
    /// Default implementation provided. Feel free to implement your own version if needed.
    ///
    /// ```swift
    /// extension NetworkingResponseRoute {
    ///
    ///     func task(priority: TaskPriority? = nil) -> Task<Serializer.SerializedObject, Error> {
    ///         Task(priority: priority) {
    ///             try await self.run
    ///         }
    ///     }
    /// }
    /// ```
    /// - Returns: A Task that contains your serialized object
    func task(priority: TaskPriority? = nil) -> Task<Serializer.SerializedObject, Error> {
        Task(priority: priority) {
            try await self.run
        }
    }

    /// Runs the `NetworkingResponseRoute`
    ///
    /// Default implementation provided. Feel free to implement your own version if needed.
    ///
    /// ```swift
    /// extension NetworkingResponseRoute {
    ///
    ///     var result: Result<Serializer.SerializedObject, Error> {
    ///         get async {
    ///             await Result { try await self.run }
    ///         }
    ///     }
    /// }
    /// ```
    /// - Returns: A Result type that contains a serialized object
    var result: Result<Serializer.SerializedObject, Error> {
        get async {
            await Result { try await self.run }
        }
    }

    /// Runs the `NetworkingResponseRoute`
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
                 completion: (@Sendable (Result<Serializer.SerializedObject, Error>) -> Void)?) -> Task<Serializer.SerializedObject, Error> {
        let requestTask = self.task(priority: priority)
        Task(priority: priority) {
            let result = await requestTask.result
            queue.async { completion?(result) }
        }
        return requestTask
    }

    var mockSerializedResult: Result<Serializer.SerializedObject, Error>? { nil }
    var repeater: Repeater? { nil }
}

public extension NetworkingResponseRoute {
    typealias Repeater = @Sendable (_ result: Result<Serializer.SerializedObject, Error>,
                                    _ urlRequest: URLRequest?,
                                    _ response: URLResponse?,
                                    _ repeatCount: Int) async -> NetworkingRetrierResult
}
