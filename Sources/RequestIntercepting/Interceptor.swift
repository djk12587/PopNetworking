//
//  File.swift
//  
//
//  Created by Dan_Koza on 11/10/21.
//

import Foundation

/// An `Interceptor` allows you to utilize multiple ``NetworkingRequestInterceptor``'s for a request.
///
/// - Attention: All ``NetworkingRequestAdapter``'s will run sequentially and potentially throw ann `Error` or `[Error]`. ``NetworkingRequestRetrier``'s will run until a retry results in a successful response.
public struct Interceptor: NetworkingRequestInterceptor {

    let adapters: [NetworkingRequestAdapter]
    let retriers: [NetworkingRequestRetrier]

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
        var errors: [Error] = []
        var adaptedRequest = urlRequest
        for adapter in adapters {
            do {
                adaptedRequest = try await adapter.adapt(urlRequest: adaptedRequest)
            }
            catch {
                errors.append(error)
            }
        }

        if errors.isEmpty {
            return adaptedRequest
        }
        else if errors.count == 1, let onlyError = errors.first {
            throw onlyError
        } else {
            throw errors
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
            case .retryWithDelay(let delay):
                try? await Task.sleep(nanoseconds: UInt64(delay) * 1_000_000_000)
                return retryResult
            case .doNotRetry:
                return await retry(urlRequest: urlRequest, dueTo: error, urlResponse: urlResponse, retryCount: retryCount, retriers: pendingRetriers)
        }
    }
}
