//
//  File.swift
//  
//
//  Created by Dan_Koza on 2/8/21.
//

import Foundation

extension NetworkingSession {
    internal actor RouteDataTask<Route: NetworkingRoute> {

        private let route: Route
        private var retryCount = 0
        private var repeatCount = 0
        private weak var networkingSessionDelegate: NetworkingSessionDelegate?

        init(route: Route,
             networkingSessionDelegate: NetworkingSessionDelegate) {
            self.route = route
            self.networkingSessionDelegate = networkingSessionDelegate
        }

        var urlRequestResult: Result<URLRequest, Error> {
            Result(catching: { try route.urlRequest })
        }

        func execute(adapter: NetworkingRequestAdapter?, adapt urlRequestResult: Result<URLRequest, Error>) async -> Result<URLRequest, Error> {
            do {
                let urlRequest = try urlRequestResult.get()
                let adaptedUrlRequest = try await adapter?.adapt(urlRequest: urlRequest)
                return .success(adaptedUrlRequest ?? urlRequest)
            }
            catch {
                return .failure(error)
            }
        }

        func execute(_ urlRequestResult: Result<URLRequest, Error>,
                     on urlSession: URLSessionProtocol) async -> (Result<Data, Error>, HTTPURLResponse?) {
            do {
                let urlRequest = try urlRequestResult.get()
                let (responseData, response) = try await urlSession.data(for: urlRequest)
                return (.success(responseData), response as? HTTPURLResponse)
            }
            catch {
                return (.failure(error), nil)
            }
        }

        func executeResponseSerializer(result: Result<Data, Error>,
                                       response: HTTPURLResponse?) -> Result<Route.ResponseSerializer.SerializedObject, Error> {
            return route.responseSerializer.serialize(result: result, urlResponse: response)
        }

        func executeRetrier(retrier: NetworkingRequestRetrier?,
                            serializedResult: Result<Route.ResponseSerializer.SerializedObject, Error>,
                            urlRequestResult: Result<URLRequest, Error>,
                            response: HTTPURLResponse?) async throws -> Result<Route.ResponseSerializer.SerializedObject, Error> {
            guard
                let retrier = retrier,
                let networkingSessionDelegate = networkingSessionDelegate,
                let error = serializedResult.error
            else { return serializedResult }

            switch await retrier.retry(urlRequest: try? urlRequestResult.get(),
                                       dueTo: error,
                                       urlResponse: response,
                                       retryCount: retryCount) {
                case .retry:
                    retryCount.increment()
                    return try await networkingSessionDelegate.retry(self, delay: nil)

                case .retryWithDelay(let delay):
                    retryCount.increment()
                    return try await networkingSessionDelegate.retry(self, delay: delay)

                case .doNotRetry:
                    return serializedResult
            }
        }

        func executeRepeater(serializedResult: Result<Route.ResponseSerializer.SerializedObject, Error>,
                             response: HTTPURLResponse?) async throws -> Result<Route.ResponseSerializer.SerializedObject, Error> {
            guard
                let routeRetrier = route.repeater,
                let networkingSessionDelegate = networkingSessionDelegate
            else { return serializedResult }

            switch try await routeRetrier(serializedResult, response, repeatCount) {
                case .retry:
                    repeatCount.increment()
                    return try await networkingSessionDelegate.retry(self, delay: nil)

                case .retryWithDelay(let delay):
                    repeatCount.increment()
                    return try await networkingSessionDelegate.retry(self, delay: delay)

                case .doNotRetry:
                    return serializedResult
            }
        }
    }
}

private extension Int {
    mutating func increment() {
        self += 1
    }
}

internal extension Result {
    var error: Error? {
        guard case let .failure(error) = self else { return nil }
        return error
    }
}
