//
//  File.swift
//  
//
//  Created by Dan_Koza on 11/10/21.
//

import Foundation

/// A `RouteInterceptor` allows you to utilize multiple ``NetworkingInterceptor``'s for a request.
///
/// - Attention: All ``NetworkingAdapter``'s will run until one fails. ``NetworkingRetrier``'s will run until a retry results in a successful response.
public struct RouteInterceptor: Sendable, NetworkingInterceptor {

    private let adapters: [NetworkingAdapter]
    private let retriers: [NetworkingRetrier]

    public init(requestInterceptors: [NetworkingInterceptor]) {
        self.adapters = requestInterceptors.sortedByPriority
        self.retriers = requestInterceptors.sortedByPriority
    }

    public init(adapters: [NetworkingAdapter] = [],
                retriers: [NetworkingRetrier] = []) {
        self.adapters = adapters.sortedByPriority
        self.retriers = retriers.sortedByPriority
    }

    public func adapt(urlRequest: URLRequest) async throws -> URLRequest {
        var request = urlRequest
        for adapter in self.adapters {
            request = try await adapter.adapt(urlRequest: request)
        }
        return request
    }

    public func retry(urlRequest: URLRequest?, dueTo error: Error, urlResponse: URLResponse?, retryCount: Int) async -> NetworkingRetrierResult {
        for retrier in self.retriers {
            let result = await retrier.retry(urlRequest: urlRequest,
                                             dueTo: error,
                                             urlResponse: urlResponse,
                                             retryCount: retryCount)
            if case .doNotRetry = result { continue }
            return result
        }
        return .doNotRetry
    }
}
