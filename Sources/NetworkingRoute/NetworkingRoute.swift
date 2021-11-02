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

    /// ``parameterEncoding`` is responsible for encoding all of your network request's parameters.
    var parameterEncoding: NetworkingRequestParameterEncoding { get }

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

    /// Allows you to mock a response. Mainly used for testing purposes.
    var mockResponse: Result<ResponseSerializer.SerializedObject, Error>? { get }

    /// Task which executes the HTTP request, and parses the networking response into whatever type is set for `ResponseSerializer.SerializedObject`
    var asyncTask: Task<ResponseSerializer.SerializedObject, Error> { get }
}

public extension NetworkingRoute {

    var session: NetworkingSession { .shared }
    var headers: NetworkingRouteHttpHeaders? { nil }
    var mockResponse: Result<ResponseSerializer.SerializedObject, Error>? { nil }

    /// Default implementation. Feel free to implement your own version if needed.
    var urlRequest: URLRequest {
        get throws {
            guard let url = URL(string: baseUrl.appending(path)) else { throw NetworkingRouteError.invalidUrl }
            var mutableRequest = URLRequest(url: url)
            mutableRequest.httpMethod = method.rawValue
            try parameterEncoding.encodeParams(into: &mutableRequest)
            headers?.forEach { mutableRequest.addValue($0.value, forHTTPHeaderField: $0.key) }
            return mutableRequest
        }
    }

    /// Default implementation. Feel free to implement your own version if needed.
    var asyncTask: Task<ResponseSerializer.SerializedObject, Error> {
        session.execute(route: self)
    }

    var asyncRequest: Result<ResponseSerializer.SerializedObject, Error> {
        get async { await asyncTask.result }
    }

    @discardableResult
    func request(completion: @escaping (Result<ResponseSerializer.SerializedObject, Error>) -> Void) -> Task<ResponseSerializer.SerializedObject, Error> {
        let requestTask = asyncTask
        Task { completion(await requestTask.result) }
        return requestTask
    }
}
