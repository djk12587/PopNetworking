//
//  NetworkRoute.swift
//  CrustyNetworking
//
//  Created by Daniel Koza on 1/7/21.
//  Copyright © 2021 Daniel Koza. All rights reserved.
//

import Foundation

public protocol URLRequestConvertible {
    func asURLRequest() throws -> URLRequest
}

public protocol NetworkingRoute: URLRequestConvertible {

    typealias NetworkingRouteHttpHeaders = [String : String]

    //--Request Building--//
    var baseURL: String { get }
    var path: String { get }
    var method: NetworkingRouteHttpMethod { get }
    var headers: NetworkingRouteHttpHeaders? { get }
    var parameterEncoding: NetworkingRequestParameterEncodingStyle { get }
    var session: NetworkingSession { get }

    //--Response Handling--//
    associatedtype ResponseSerializer: NetworkingResponseSerializer
    var responseSerializer: ResponseSerializer { get }

    ///Responsible for turning a NetworkingRoute object into a Result<ResponseSerializer.SerializedObject, Error>
    func request(completion: @escaping (Result<ResponseSerializer.SerializedObject, Error>) -> Void) -> URLSessionTask?
}

public enum NetworkingRequestParameterEncodingStyle {
    case json(params: [String: Any]?)
    case jsonData(encodedParams: Data?)
    case url(params: [String: Any]?)
}

public enum NetworkingRouteHttpMethod: String {
    case get
    case post
    case delete
    case put
}

public enum NetworkingRouteError: Error {
    case invalidUrl
    case jsonParameterEncodingFailed(reason: Error)
}
