//
//  NetworkRoute+Extensions.swift
//  PopNetworking
//
//  Created by Daniel Koza on 1/8/21.
//  Copyright © 2021 Daniel Koza. All rights reserved.
//

import Foundation

public extension NetworkingRoute {
    var session: NetworkingSession { .shared }
    var headers: NetworkingRouteHttpHeaders? { nil }
    var mockResponse: Result<ResponseSerializer.SerializedObject, Error>? { nil }
}

extension NetworkingRoute {

    /// This is a default implementation. If you require a custom implementation, you can implement your own `func asUrlRequest() throws -> URLRequest`
    public func asUrlRequest() throws -> URLRequest {

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
    public func request(runCompletionHandlerOn queue: DispatchQueue = .main,
                        completion: @escaping (Result<ResponseSerializer.SerializedObject, Error>) -> Void) -> Cancellable {
        return session.execute(route: self,
                               runCompletionHandlerOn: queue,
                               completionHandler: completion)
    }
}
