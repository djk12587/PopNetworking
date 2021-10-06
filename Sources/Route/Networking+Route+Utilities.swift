//
//  File.swift
//  
//
//  Created by Dan_Koza on 10/4/21.
//

import Foundation

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

public struct MockedCancellable: Cancellable {
    public func cancel() {}
}

extension URLSessionDataTask {
    public struct RawResponse {
        public let urlRequest: URLRequest?
        public let urlResponse: HTTPURLResponse?
        public let data: Data?
        public let error: Error?
    }
}
