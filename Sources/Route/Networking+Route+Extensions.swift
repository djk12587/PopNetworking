//
//  NetworkRoute+Extensions.swift
//  CrustyNetworking
//
//  Created by Daniel Koza on 1/8/21.
//  Copyright © 2021 Daniel Koza. All rights reserved.
//

import Foundation

public extension NetworkingRoute {

    var headers: [String: String]? { nil }
    var session: NetworkingSession { NetworkingSession() }
    var jsonResponseDecoder: JSONDecoder? { nil }
}

extension NetworkingRoute {

    public func asURLRequest() throws -> URLRequest {

        guard let url = Foundation.URL(string: baseURL)?.appendingPathComponent(path) else {
            throw NetworkingRouteError.invalidUrl
        }

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

    @discardableResult
    public func request(completion: @escaping (Result<ResponseSerializer.SerializedObject, Error>) -> Void) -> URLSessionTask? {
        return session
            .start(request: self)
            .response(serializer: responseSerializer, completionHandler: completion)
            .task
    }
}
