//
//  File.swift
//  
//
//  Created by Dan_Koza on 11/10/21.
//

import Foundation

/// A `RouteInterceptor` allows you to utilize multiple ``NetworkingRouteInterceptor``'s for a request.
///
/// - Attention: All ``NetworkingRouteAdapter``'s will run until one fails. ``NetworkingRouteRetrier``'s will run until a retry results in a successful response.
public struct RouteInterceptor: Sendable, NetworkingRouteInterceptor {

    private let adapters: [NetworkingRouteAdapter]
    private let retriers: [NetworkingRouteRetrier]

    public init(requestInterceptors: [NetworkingRouteInterceptor]) {
        self.adapters = requestInterceptors
        self.retriers = requestInterceptors
    }

    public init(adapters: [NetworkingRouteAdapter] = [],
                retriers: [NetworkingRouteRetrier] = []) {
        self.adapters = adapters
        self.retriers = retriers
    }

    public func adapt(urlRequest: URLRequest) async throws -> URLRequest {
        return try await adapt(urlRequest: urlRequest, with: adapters)
    }

    private func adapt(urlRequest: URLRequest, with adapters: [NetworkingRouteAdapter]) async throws -> URLRequest {
        var pendingAdapters = adapters
        guard let adapter = pendingAdapters.first else { return urlRequest }
        pendingAdapters.removeFirst()
        let adaptedRequest = try await adapter.adapt(urlRequest: urlRequest)
        return try await adapt(urlRequest: adaptedRequest, with: pendingAdapters)
    }

    public func retry(urlRequest: URLRequest?, dueTo error: Error, urlResponse: URLResponse?, retryCount: Int) async -> NetworkingRouteRetrierResult {
        return await retry(urlRequest: urlRequest, dueTo: error, urlResponse: urlResponse, retryCount: retryCount, retriers: retriers)
    }

    private func retry(urlRequest: URLRequest?,
                       dueTo error: Error,
                       urlResponse: URLResponse?,
                       retryCount: Int,
                       retriers: [NetworkingRouteRetrier]) async -> NetworkingRouteRetrierResult {
        var pendingRetriers = retriers
        guard let retrier = pendingRetriers.first else { return .doNotRetry }
        pendingRetriers.removeFirst()

        let retryResult = await retrier.retry(urlRequest: urlRequest, dueTo: error, urlResponse: urlResponse, retryCount: retryCount)
        switch retryResult {
            case .retry:
                return retryResult
            case .retryWithDelay(let delay):
                try? await Task.sleep(nanoseconds: UInt64(delay) * 1_000_000_000)
                return retryResult
            case .doNotRetry:
                return await retry(urlRequest: urlRequest, dueTo: error, urlResponse: urlResponse, retryCount: retryCount, retriers: pendingRetriers)
        }
    }
}
