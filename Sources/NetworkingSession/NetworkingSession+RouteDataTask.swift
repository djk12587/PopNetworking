//
//  File.swift
//  
//
//  Created by Dan_Koza on 2/8/21.
//

import Foundation

internal protocol RouteDataTaskDelegate: AnyObject, Sendable {

    func retry<Route: NetworkingRoute>(_ routeDataTask: NetworkingSession.RouteDataTask<Route>,
                                       delay: TimeInterval?) async -> Result<Route.ResponseSerializer.SerializedObject, Error>

}

extension NetworkingSession {

    internal struct RouteDataTask<Route: NetworkingRoute>: Sendable {

        private actor SafeCounters {

            private(set) var retryCount = 0
            private(set) var repeatCount = 0

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
        }

        private let route: Route
        private let counters = SafeCounters()
        private weak var delegate: RouteDataTaskDelegate?

        init(route: Route, delegate: RouteDataTaskDelegate?) {
            self.route = route
            self.delegate = delegate
        }

        func buildURLRequest(adapter: NetworkingRouteAdapter?) async -> Result<URLRequest, Error> {
            return await Result {
                let urlRequest = try self.route.urlRequest
                let adaptedUrlRequest = try await adapter?.adapt(urlRequest: urlRequest)
                return adaptedUrlRequest ?? urlRequest
            }
        }

        func start(urlRequestResult: Result<URLRequest, Error>,
                   on urlSession: URLSessionProtocol) async -> (Result<Route.ResponseSerializer.SerializedObject, Error>, URLResponse?) {
            if let mockSerializedResult = await self.route.mockSerializedResult {
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

        func executeRetrier(retrier: NetworkingRouteRetrier?,
                            serializedResult: Result<Route.ResponseSerializer.SerializedObject, Error>,
                            urlRequest: URLRequest?,
                            response: URLResponse?) async -> Result<Route.ResponseSerializer.SerializedObject, Error> {
            guard
                let retrier = retrier,
                let delegate = self.delegate,
                let error = serializedResult.error
            else {
                await self.counters.resetRetryCount()
                return serializedResult
            }

            switch await retrier.retry(urlRequest: urlRequest,
                                       dueTo: error,
                                       urlResponse: response,
                                       retryCount: self.counters.retryCount) {
                case .retry:
                    await self.counters.incrementRetryCount()
                    return await delegate.retry(self, delay: nil)

                case .retryWithDelay(let delay):
                    await self.counters.incrementRetryCount()
                    return await delegate.retry(self, delay: delay)

                case .doNotRetry:
                    await self.counters.resetRetryCount()
                    return serializedResult
            }
        }

        func executeRepeater(serializedResult: Result<Route.ResponseSerializer.SerializedObject, Error>,
                             response: URLResponse?) async -> Result<Route.ResponseSerializer.SerializedObject, Error> {
            guard
                let routeRetrier = self.route.repeater,
                let delegate = self.delegate
            else {
                await self.counters.resetRepeatCount()
                return serializedResult
            }

            switch await routeRetrier(serializedResult, response, self.counters.repeatCount) {
                case .retry:
                    await self.counters.incrementRepeatCount()
                    return await delegate.retry(self, delay: nil)

                case .retryWithDelay(let delay):
                    await self.counters.incrementRepeatCount()
                    return await delegate.retry(self, delay: delay)

                case .doNotRetry:
                    await self.counters.incrementRepeatCount()
                    return serializedResult
            }
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
