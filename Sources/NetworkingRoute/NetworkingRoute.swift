//
//  NetworkRoute.swift
//  PopNetworking
//
//  Created by Daniel Koza on 1/7/21.
//  Copyright © 2021 Daniel Koza. All rights reserved.
//

import Foundation

/// ``NetworkingRoute`` is a protocol that is responsible for declaring everything needed to create `URLRequest`s and parse the response into any desired custom type.
public protocol NetworkingRoute {

    typealias NetworkingRouteHttpHeaders = [String : String]

    /// The ``NetworkingSession`` used to execute the HTTP request
    var session: NetworkingSession { get }

    /// HTTP base URL represented as a `String`
    var baseUrl: String { get }
    /// HTTP url path as a `String`
    var path: String { get }
    /// HTTP method
    var method: NetworkingRouteHttpMethod { get }
    /// HTTP headers
    var headers: NetworkingRouteHttpHeaders? { get }

    /// <doc:/documentation/PopNetworking/NetworkingRoute/parameterEncoding-5o5po> is responsible for encoding all of your network request's parameters.
    var parameterEncoding: NetworkingRequestParameterEncoding? { get }

    /// ``urlRequest-793sf`` is responsible for converting `self` into a `URLRequest`
    var urlRequest: URLRequest { get throws }

    //--Response Handling--//

    /// `ResponseSerializer` allows for plug and play networking response serialization.
    ///
    /// For examples of prebuilt `NetworkingResponseSerializer`'s see ``NetworkingResponseSerializers``
    associatedtype ResponseSerializer: NetworkingResponseSerializer

    /// A `ResponseSerializer` is responsible for parsing the raw response of an HTTP request into a more usable object, like a Model object. The `ResponseSerializer` must adhere to ``NetworkingResponseSerializer``
    ///
    /// Prebuilt `ResponseSerializer`s can be found here: ``NetworkingResponseSerializers``.
    var responseSerializer: ResponseSerializer { get }

    /// A `Repeater` allows you to retry the entire request if needed. This can be used if you have to repeatedly poll an endpoint to wait for a specific status to be returned.
    var repeater: Repeater? { get }

    /// <doc:/documentation/PopNetworking/NetworkingRoute/urlRequest-5u991>'s default implementation will use <doc:/documentation/PopNetworking/NetworkingRoute/timeoutInterval-9db54> when instantiating a `URLRequest(url: timeoutInterval:)`.
    ///
    /// - Note: If nil, the default, 60 seconds is used.
    var timeoutInterval: TimeInterval? { get }

    /// Allows you to mock a response. Mainly used for testing purposes.
    var mockResponse: Result<ResponseSerializer.SerializedObject, Error>? { get }
}

public extension NetworkingRoute {

    /// Default implementation. Feel free to implement your own version if needed.
    var urlRequest: URLRequest {
        get throws {
            guard let url = URL(string: baseUrl.appending(path)) else {
                throw URLError(.badURL, userInfo: ["baseUrl": baseUrl, "path": path])
            }

            var mutableRequest = URLRequest(url: url, timeoutInterval: timeoutInterval ?? 60.0)
            mutableRequest.httpMethod = method.rawValue
            try parameterEncoding?.encodeParams(into: &mutableRequest)
            headers?.forEach { mutableRequest.addValue($0.value, forHTTPHeaderField: $0.key) }
            return mutableRequest
        }
    }

    var run: ResponseSerializer.SerializedObject {
        get async throws {
            try await session.execute(route: self)
        }
    }

    func task(priority: TaskPriority? = nil) -> Task<ResponseSerializer.SerializedObject, Error> {
        Task(priority: priority) {
            try await run
        }
    }

    var result: Result<ResponseSerializer.SerializedObject, Error> {
        get async {
            await Result { try await run }
        }
    }

    @discardableResult
    func request(priority: TaskPriority? = nil,
                 completeOn queue: DispatchQueue = .main,
                 completion: @escaping (Result<ResponseSerializer.SerializedObject, Error>) -> Void) -> Task<ResponseSerializer.SerializedObject, Error> {
        let requestTask = task(priority: priority)
        Task(priority: priority) {
            let result = await requestTask.result
            queue.async { completion(result) }
        }
        return requestTask
    }

    var session: NetworkingSession { .shared }
    var headers: NetworkingRouteHttpHeaders? { nil }
    var parameterEncoding: NetworkingRequestParameterEncoding? { nil }
    var timeoutInterval: TimeInterval? { nil }
    var repeater: Repeater? { nil }
    var mockResponse: Result<ResponseSerializer.SerializedObject, Error>? { nil }
}

public extension NetworkingRoute {
    typealias Repeater = (_ result: Result<ResponseSerializer.SerializedObject, Error>,
                          _ response: HTTPURLResponse?,
                          _ repeatCount: Int) async -> NetworkingRequestRetrierResult
}
