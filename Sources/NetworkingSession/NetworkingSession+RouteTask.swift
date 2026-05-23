//
//  NetworkingSession+RouteTask.swift
//  PopNetworking
//

import Foundation

extension NetworkingSession {

    /// Connect-attempt state shared by ``ResponseRouteTask`` and ``StreamRouteTask``.
    ///
    /// Owns the mutable state that survives across retry attempts (the retry counter and the
    /// most-recently-built `URLRequest`) plus the helpers that operate on that state
    /// (``executeAdapter(_:on:)`` and ``consultRetriers(error:urlRequest:urlResponse:retriers:)``).
    /// The response task additionally manages a repeat counter; that lives on
    /// ``ResponseRouteTask`` because streaming has no repeater concept.
    internal actor RouteTask {

        private(set) var retryCount = 0
        private(set) var currentUrlRequest: URLRequest?

        /// Resets the retry counter. The session calls this on a successful terminal result.
        func resetRetryCount() {
            self.retryCount = 0
        }

        /// Resolves the `URLRequest` to use for the next attempt: returns the cached one if
        /// present, otherwise builds it with the supplied async closure and caches the result.
        func urlRequestResult(buildIfNeeded: @Sendable () async throws -> URLRequest) async -> Result<URLRequest, Error> {
            if let cached = self.currentUrlRequest {
                return .success(cached)
            }
            do {
                let built = try await buildIfNeeded()
                self.currentUrlRequest = built
                return .success(built)
            } catch {
                return .failure(error)
            }
        }

        /// Runs a single adapter against the current `urlRequestResult` and caches the
        /// adapted request. Failures (either the input was already a failure, or the adapter
        /// threw) propagate via the returned `Result`.
        func executeAdapter(_ adapter: NetworkingAdapter,
                            on urlRequestResult: Result<URLRequest, Error>) async -> Result<URLRequest, Error> {
            guard let urlRequest = try? urlRequestResult.get() else { return urlRequestResult }
            do {
                let adapted = try await adapter.adapt(urlRequest: urlRequest)
                self.currentUrlRequest = adapted
                return .success(adapted)
            } catch {
                return .failure(error)
            }
        }

        /// Iterates the supplied retriers in order; the first non-`.doNotRetry` decision wins.
        /// Increments ``retryCount`` on retry, resets it on `.doNotRetry`. Caller is
        /// responsible for only invoking this on an error (success → call ``resetRetryCount()``).
        func consultRetriers(error: Error,
                             urlRequest: URLRequest?,
                             urlResponse: URLResponse?,
                             retriers: [NetworkingRetrier]) async -> NetworkingRetrierResult {
            for retrier in retriers {
                let decision = await retrier.retry(urlRequest: urlRequest,
                                                   dueTo: error,
                                                   urlResponse: urlResponse,
                                                   retryCount: self.retryCount)
                if case .doNotRetry = decision { continue }
                self.retryCount += 1
                return decision
            }
            self.retryCount = 0
            return .doNotRetry
        }
    }
}
