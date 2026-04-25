//
//  File.swift
//
//
//  Created by Dan_Koza on 2/8/21.
//

import Foundation

extension NetworkingSession {

    internal struct RouteDataTask<Route: NetworkingRoute>: Sendable {

        private actor SafeMutableData {

            private(set) var retryCount = 0
            private(set) var repeatCount = 0
            private(set) var currentUrlRequest: URLRequest?

            func incrementRetryCount() {
                self.retryCount.increment()
            }

            func incrementRepeatCount() {
                self.repeatCount.increment()
            }

            func resetRetryCount() {
                self.retryCount.reset()
            }

            func resetRepeatCount() {
                self.repeatCount.reset()
            }

            func set(currentUrlRequest: URLRequest) {
                self.currentUrlRequest = currentUrlRequest
            }
        }

        private let route: Route
        private let mutableData = SafeMutableData()
        internal var adapter: NetworkingAdapter? { self.route.adapter }
        internal var retrier: NetworkingRetrier? { self.route.retrier }
        internal var interceptor: NetworkingInterceptor? { self.route.interceptor }

        init(route: Route) {
            self.route = route
        }

        var urlRequestResult: Result<URLRequest, Error> {
            get async {
                return await Result {
                    if let currentUrlRequest = await self.mutableData.currentUrlRequest {
                        return currentUrlRequest
                    } else {
                        let routeRequest = try await self.route.urlRequest
                        await self.mutableData.set(currentUrlRequest: routeRequest)
                        return routeRequest
                    }
                }
            }
        }

        func executeAdapter(_ adapter: NetworkingAdapter,
                            on urlRequestResult: Result<URLRequest, Error>) async -> Result<URLRequest, Error> {
            guard
                let urlRequest = try? urlRequestResult.get()
            else { return urlRequestResult }

            return await Result {
                let adaptedUrlRequest = try await adapter.adapt(urlRequest: urlRequest)
                await self.mutableData.set(currentUrlRequest: adaptedUrlRequest)
                return adaptedUrlRequest
            }
        }

        func start(urlRequestResult: Result<URLRequest, Error>,
                   on urlSession: URLSessionProtocol) async -> (Result<Route.ResponseSerializer.SerializedObject, Error>, URLResponse?) {
            if let mockSerializedResult = self.route.mockSerializedResult {
                return (mockSerializedResult, nil)
            } else {
                var responseResult = await Result {
                    let urlRequest = try urlRequestResult.get()
                    return try await urlSession.data(for: urlRequest)
                }

                responseResult = await self.executeResponseValidator(responseResult: responseResult)
                let serializedResponse = await self.executeResponseSerializer(responseResult: responseResult)

                return (serializedResponse, try? responseResult.get().1)
            }
        }

        /// Evaluates the retrier chain against the given attempt. Iterates `retriers` in order; the
        /// first retrier returning a non-`.doNotRetry` decision wins and its decision is returned.
        /// Manages `retryCount` increments and resets at the same logical points as before.
        func executeRetrier(serializedResult: Result<Route.ResponseSerializer.SerializedObject, Error>,
                            urlRequest: URLRequest?,
                            urlResponse: URLResponse?,
                            retriers: [NetworkingRetrier]) async -> NetworkingRetrierResult {
            guard case .failure(let error) = serializedResult else {
                await self.mutableData.resetRetryCount()
                return .doNotRetry
            }

            for retrier in retriers {
                let decision = await retrier.retry(urlRequest: urlRequest,
                                                   dueTo: error,
                                                   urlResponse: urlResponse,
                                                   retryCount: self.mutableData.retryCount)
                if case .doNotRetry = decision { continue }
                await self.mutableData.incrementRetryCount()
                return decision
            }

            await self.mutableData.resetRetryCount()
            return .doNotRetry
        }

        /// Evaluates the route's repeater (if any) against the attempt's terminal state and returns
        /// its decision. Manages `repeatCount` increments and resets.
        func executeRepeater(serializedResult: Result<Route.ResponseSerializer.SerializedObject, Error>,
                             urlRequest: URLRequest?,
                             urlResponse: URLResponse?) async -> NetworkingRetrierResult {
            guard let repeater = self.route.repeater else {
                await self.mutableData.resetRepeatCount()
                return .doNotRetry
            }

            let decision = await repeater(serializedResult,
                                          urlRequest,
                                          urlResponse,
                                          self.mutableData.repeatCount)
            switch decision {
                case .doNotRetry:
                    await self.mutableData.resetRepeatCount()
                case .retry, .retryWithDelay:
                    await self.mutableData.incrementRepeatCount()
            }
            return decision
        }

        private func executeResponseValidator(responseResult: Result<(Data, URLResponse), Error>) async -> Result<(Data, URLResponse), Error> {
            do {
                try await self.route.responseValidator?.validate(responseResult: responseResult)
                return responseResult
            } catch {
                return .failure(error)
            }
        }

        private func executeResponseSerializer(responseResult: Result<(Data, URLResponse), Error>) async -> Result<Route.ResponseSerializer.SerializedObject, Error> {
            return await self.route.responseSerializer.serialize(responseResult: responseResult)
        }

    }
}

private extension Int {
    mutating func increment() {
        self += 1
    }

    mutating func reset() {
        self = 0
    }
}

internal extension Result {
    var error: Error? {
        guard case let .failure(error) = self else { return nil }
        return error
    }
}

internal extension Result where Failure == Error {
    init(asyncCatching: @Sendable () async throws -> Success) async {
        do {
            let success = try await asyncCatching()
            self = .success(success)
        } catch {
            self = .failure(error)
        }
    }
}
