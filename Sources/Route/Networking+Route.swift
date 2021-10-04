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

/// `NetworkingRequestParameterEncoding` declares how your requests parameters should be added to a `URLRequest`
public enum NetworkingRequestParameterEncoding {
    case json(params: [String: Any]?)
    case jsonData(encodedParams: Data?)
    case url(params: [String: Any]?)
}

public enum NetworkingRouteHttpMethod: String {
    case get
    case post
    case delete
    case put
    case patch
}

/// Potential errors that can be returned when attempting to create a `URLRequest` from a `NetworkingRoute`
public enum NetworkingRouteError: Error {
    case invalidUrl
    case jsonParameterEncodingFailed(reason: Error)

    public enum AggregatedRoutes: Error {
        case routeNeverFinished
        case multiFailure([Error])
    }
}

public protocol Cancellable {
    ///Cancels a `NetworkingRoute`
    func cancel()
}

public struct NetworkingRawResponse {
    public let urlRequest: URLRequest?
    public let urlResponse: HTTPURLResponse?
    public let data: Data?
    public let error: Error?
}

public struct MockedCancellable: Cancellable {
    public func cancel() {}
}
