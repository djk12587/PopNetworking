//
//  NetworkRoute.swift
//  PopNetworking
//
//  Created by Daniel Koza on 1/7/21.
//  Copyright © 2021 Daniel Koza. All rights reserved.
//

import Foundation

/// A ``NetworkingRoute`` encapsulates everything required to build a `URLRequest` and serialize the `URLRequest`'s response with the specified ``NetworkingResponseSerializer``
public protocol NetworkingRoute {

    typealias NetworkingRouteHttpHeaders = [String : String]
    /// The ``NetworkingSession`` used to execute the HTTP request
    var session: NetworkingSession { get }

    /// HTTP base URL represented as a `String`
    var baseUrl: String { get }
    /// HTTP url path
    var path: String { get }
    /// HTTP method
    var method: NetworkingRouteHttpMethod { get }
    /// HTTP headers
    var headers: NetworkingRouteHttpHeaders? { get }
    /// HTTP parameters
    var parameterEncoding: NetworkingRequestParameterEncoding { get }

    /// Turns a ``NetworkingRoute`` into  a `URLRequest`
    var urlRequest: URLRequest { get throws }

    //--Response Handling--//
    associatedtype ResponseSerializer: NetworkingResponseSerializer
    /// Responsible for turning the raw response of an HTTP request into a desired response like a Model object
    var responseSerializer: ResponseSerializer { get }

    /// Use ``mockResponse-2yjpw`` for testing purposes.
    /// If ``mockResponse-2yjpw`` is not nil, the ``mockResponse-2yjpw`` is what will be returned when ``request(runCompletionHandlerOn:completion:)-9tv4l`` is called.
    /// By default this property is nil.
    var mockResponse: Result<ResponseSerializer.SerializedObject, Error>? { get }

    /// Responsible for turning the ``NetworkingRoute``  into a `Result<ResponseSerializer.SerializedObject, Error>`. By default, this function will execute your HTTP request.
    func request(runCompletionHandlerOn queue: DispatchQueue, completion: @escaping (Result<ResponseSerializer.SerializedObject, Error>) -> Void) -> Cancellable
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
    @discardableResult
    func request(runCompletionHandlerOn queue: DispatchQueue = .main,
                 completion: @escaping (Result<ResponseSerializer.SerializedObject, Error>) -> Void) -> Cancellable {
        return session.execute(route: self,
                               runCompletionHandlerOn: queue,
                               completionHandler: completion)
    }
}
