//
//  File.swift
//  
//
//  Created by Dan_Koza on 11/10/21.
//

import Foundation

/// An `Interceptor` allows you to utilize multiple `NetworkingRequestInterceptor`'s for a request.
///
/// - Attention: All ``NetworkingRequestAdapter``'s will run until one fails. ``NetworkingRequestRetrier``'s will run until a retry results in a successful response.
public class Interceptor: NetworkingRequestInterceptor {

    private let adapters: [NetworkingRequestAdapter]
    private let retriers: [NetworkingRequestRetrier]

    public init(requestInterceptors: [NetworkingRequestInterceptor]) {
        self.adapters = requestInterceptors
        self.retriers = requestInterceptors
    }

    public init(adapters: [NetworkingRequestAdapter] = [],
                retriers: [NetworkingRequestRetrier] = []) {
        self.adapters = adapters
        self.retriers = retriers
    }

    public func adapt(urlRequest: URLRequest) async throws -> URLRequest {
        return try await adapt(urlRequest: urlRequest, with: adapters)
    }

    private func adapt(urlRequest: URLRequest, with adapters: [NetworkingRequestAdapter]) async throws -> URLRequest {
        var pendingAdapters = adapters
        guard let adapter = pendingAdapters.first else { return urlRequest }
        pendingAdapters.removeFirst()

        do {
            let adaptedRequest = try await adapter.adapt(urlRequest: urlRequest)
            return try await adapt(urlRequest: adaptedRequest, with: pendingAdapters)
        } catch {
            throw error
        }
    }

    public func retry(urlRequest: URLRequest?, dueTo error: Error, urlResponse: HTTPURLResponse?, retryCount: Int) async -> NetworkingRequestRetrierResult {
        return await retry(urlRequest: urlRequest, dueTo: error, urlResponse: urlResponse, retryCount: retryCount, retriers: retriers)
    }

    private func retry(urlRequest: URLRequest?,
                       dueTo error: Error,
                       urlResponse: HTTPURLResponse?,
                       retryCount: Int,
                       retriers: [NetworkingRequestRetrier]) async -> NetworkingRequestRetrierResult {
        var pendingRetriers = retriers
        guard let retrier = pendingRetriers.first else { return .doNotRetry }
        pendingRetriers.removeFirst()

        let retryResult = await retrier.retry(urlRequest: urlRequest, dueTo: error, urlResponse: urlResponse, retryCount: retryCount)
        switch retryResult {
            case .retry:
                return retryResult
            case .doNotRetry:
                return await retry(urlRequest: urlRequest, dueTo: error, urlResponse: urlResponse, retryCount: retryCount, retriers: pendingRetriers)
        }
    }
}
