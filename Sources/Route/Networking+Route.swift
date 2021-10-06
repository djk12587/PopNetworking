//
//  NetworkRoute.swift
//  PopNetworking
//
//  Created by Daniel Koza on 1/7/21.
//  Copyright © 2021 Daniel Koza. All rights reserved.
//

import Foundation

/// A `NetworkingRoute` encapsulates everything required to build a `URLRequest` and serialize the `URLRequest`'s response into a `Result<ResponseSerializer.SerializedObject, Error>`
public protocol NetworkingRoute {

    typealias NetworkingRouteHttpHeaders = [String : String]

    //--Request Building--//
    var baseUrl: String { get }
    var path: String { get }
    var method: NetworkingRouteHttpMethod { get }
    var headers: NetworkingRouteHttpHeaders? { get }
    var parameterEncoding: NetworkingRequestParameterEncoding { get }
    var session: NetworkingSession { get }
    func asUrlRequest() throws -> URLRequest

    //--Response Handling--//
    associatedtype ResponseSerializer: NetworkingResponseSerializer
    var responseSerializer: ResponseSerializer { get }
    var mockResponse: Result<ResponseSerializer.SerializedObject, Error>? { get }

    ///Responsible for turning a NetworkingRoute object into a Result<ResponseSerializer.SerializedObject, Error>
    func request(runCompletionHandlerOn queue: DispatchQueue, completion: @escaping (Result<ResponseSerializer.SerializedObject, Error>) -> Void) -> Cancellable
}

public extension NetworkingRoute {

    var session: NetworkingSession { .shared }
    var headers: NetworkingRouteHttpHeaders? { nil }
    var mockResponse: Result<ResponseSerializer.SerializedObject, Error>? { nil }

    /// This is a default implementation. If you require a custom implementation, you can implement your own `func asUrlRequest() throws -> URLRequest`
    func asUrlRequest() throws -> URLRequest {

        guard let url = URL(string: baseUrl.appending(path)) else { throw NetworkingRouteError.invalidUrl }

        var mutableRequest = URLRequest(url: url)
        mutableRequest.httpMethod = method.rawValue

        switch parameterEncoding {
            case .url(let params):
                try URLEncoding.default.encode(&mutableRequest, with: params)

            case .json(let params):
                try JSONEncoding.default.encode(&mutableRequest, with: params)

            case .jsonData(let encodedParams):
                JSONEncoding.default.encode(&mutableRequest, with: encodedParams)
        }

        headers?.forEach { mutableRequest.addValue($0.value, forHTTPHeaderField: $0.key) }

        return mutableRequest
    }

    /// This is a default implementation. If you require a custom implementation, you can implement your own `func request(completion: @escaping (Result<ResponseSerializer.SerializedObject, Error>) -> Void) -> Cancellable`
    @discardableResult
    func request(runCompletionHandlerOn queue: DispatchQueue = .main,
                        completion: @escaping (Result<ResponseSerializer.SerializedObject, Error>) -> Void) -> Cancellable {
        return session.execute(route: self,
                               runCompletionHandlerOn: queue,
                               completionHandler: completion)
    }
}
