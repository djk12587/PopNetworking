//
//  Networking+RequestInterceptor.swift
//  CrustyNetworking
//
//  Created by Daniel Koza on 1/9/21.
//  Copyright © 2021 Daniel Koza. All rights reserved.
//

import Foundation

public protocol NetworkingRequestInterceptor: NetworkingRequestAdapter & NetworkingRequestRetrier {}

public protocol NetworkingRequestAdapter {
    func adapt(urlRequest: URLRequest, for session: URLSession) -> URLRequest
}

public protocol NetworkingRequestRetrier: class {
    func retry(urlRequest: URLRequest,
               dueTo error: Error,
               urlResponse: HTTPURLResponse,
               retryCount: Int,
               completion: @escaping (NetworkingRequestRetrierResult) -> Void)
}

public enum NetworkingRequestRetrierResult {
    case retry
    case doNotRetry
}
