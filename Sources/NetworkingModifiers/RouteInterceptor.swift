//
//  File.swift
//  
//
//  Created by Dan_Koza on 11/10/21.
//

import Foundation

/// A `RouteInterceptor` allows you to utilize multiple ``NetworkingRouteInterceptor``'s for a request.
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
        return try await self.adapt(urlRequest: urlRequest, with: self.adapters)
    }

    private func adapt(urlRequest: URLRequest, with adapters: [NetworkingAdapter]) async throws -> URLRequest {

        var adapters = adapters
        guard !adapters.isEmpty else { return urlRequest }

        let adapter = adapters.removeFirst()
        let adaptedRequest = try await adapter.adapt(urlRequest: urlRequest)
        return try await self.adapt(urlRequest: adaptedRequest, with: adapters)
    }

    public func retry(urlRequest: URLRequest?, dueTo error: Error, urlResponse: URLResponse?, retryCount: Int) async -> NetworkingRetrierResult {
        return await self.retry(urlRequest: urlRequest,
                                dueTo: error,
                                urlResponse: urlResponse,
                                retryCount: retryCount,
                                retriers: self.retriers)
    }

    private func retry(urlRequest: URLRequest?,
                       dueTo error: Error,
                       urlResponse: URLResponse?,
                       retryCount: Int,
                       retriers: [NetworkingRetrier]) async -> NetworkingRetrierResult {

        var retriers = retriers
        guard !retriers.isEmpty else { return .doNotRetry }

        let retrier = retriers.removeFirst()
        let retryResult = await retrier.retry(urlRequest: urlRequest,
                                              dueTo: error,
                                              urlResponse: urlResponse,
                                              retryCount: retryCount)
        switch retryResult {
            case .retry:
                return retryResult
            case .retryWithDelay(let delay):
                try? await Task.sleep(nanoseconds: UInt64(delay) * 1_000_000_000)
                return retryResult
            case .doNotRetry:
                return await self.retry(urlRequest: urlRequest,
                                        dueTo: error,
                                        urlResponse: urlResponse,
                                        retryCount: retryCount,
                                        retriers: retriers)
        }
    }
}
