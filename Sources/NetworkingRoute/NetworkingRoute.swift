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

    /// A `Retrier` allows you to retry the request if needed. This can be used if you have to repeatedly poll an endpoint to wait for a specific status to be returned.
    var retrier: Retrier? { get }

    var timeout: TimeInterval? { get }

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
            var mutableRequest = URLRequest(url: url)
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
    var retrier: Retrier? { nil }
    var timeout: TimeInterval? { nil }
    var mockResponse: Result<ResponseSerializer.SerializedObject, Error>? { nil }
}

public extension NetworkingRoute {
    typealias Retrier = (_ result: Result<ResponseSerializer.SerializedObject, Error>,
                         _ response: HTTPURLResponse?,
                         _ retryCount: Int) async throws -> NetworkingRequestRetrierResult
}

private extension Result where Failure == Error {
    init(asyncCatching: () async throws -> Success) async {
        do {
            let success = try await asyncCatching()
            self = .success(success)
        } catch {
            self = .failure(error)
        }
    }
}
