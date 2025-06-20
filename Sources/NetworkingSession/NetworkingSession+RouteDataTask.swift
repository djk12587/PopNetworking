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
             networkingSessionDelegate: NetworkingSessionDelegate?) {
            self.route = route
            self.networkingSessionDelegate = networkingSessionDelegate
        }

        func execute(on urlSession: URLSessionProtocol,
                     adapter: NetworkingRequestAdapter?) async -> (Result<Data, Error>, HTTPURLResponse?, URLRequest?) {

            let urlRequestResult: Result<URLRequest, Error> = await Result {
                let urlRequest = try route.urlRequest
                let adaptedUrlRequest = try await adapter?.adapt(urlRequest: urlRequest)
                return adaptedUrlRequest ?? urlRequest
            }

            do {
                let urlRequest = try urlRequestResult.get()
                let (responseData, response) = try await urlSession.data(for: urlRequest)
                return (.success(responseData), response as? HTTPURLResponse, urlRequest)
            }
            catch {
                return (.failure(error), nil, try? urlRequestResult.get())
            }
        }

        func executeResponseValidator(result: Result<Data, Error>,
                                      response: HTTPURLResponse?) -> Result<Data, Error> {
            do {
                try route.responseValidator?.validate(result: result, urlResponse: response)
                return result
            } catch let validationError {
                return .failure(validationError)
            }
        }

        func executeResponseSerializer(result: Result<Data, Error>,
                                       response: HTTPURLResponse?) async -> Result<Route.ResponseSerializer.SerializedObject, Error> {
            return await route.responseSerializer.serialize(result: result,
                                                            urlResponse: response)
        }

        func executeRetrier(retrier: NetworkingRequestRetrier?,
                            serializedResult: Result<Route.ResponseSerializer.SerializedObject, Error>,
                            urlRequest: URLRequest?,
                            response: HTTPURLResponse?) async -> Result<Route.ResponseSerializer.SerializedObject, Error> {
            guard
                let retrier = retrier,
                let networkingSessionDelegate = networkingSessionDelegate,
                let error = serializedResult.error
            else {
                retryCount.reset()
                return serializedResult
            }

            switch await retrier.retry(urlRequest: urlRequest,
                                       dueTo: error,
                                       urlResponse: response,
                                       retryCount: retryCount) {
                case .retry:
                    retryCount.increment()
                    return await networkingSessionDelegate.retry(self, delay: nil)

                case .retryWithDelay(let delay):
                    retryCount.increment()
                    return await networkingSessionDelegate.retry(self, delay: delay)

                case .doNotRetry:
                    retryCount.reset()
                    return serializedResult
            }
        }

        func executeRepeater(serializedResult: Result<Route.ResponseSerializer.SerializedObject, Error>,
                             response: HTTPURLResponse?) async -> Result<Route.ResponseSerializer.SerializedObject, Error> {
            guard
                let routeRetrier = route.repeater,
                let networkingSessionDelegate = networkingSessionDelegate
            else {
                repeatCount.reset()
                return serializedResult
            }

            switch await routeRetrier(serializedResult, response, repeatCount) {
                case .retry:
                    repeatCount.increment()
                    return await networkingSessionDelegate.retry(self, delay: nil)

                case .retryWithDelay(let delay):
                    repeatCount.increment()
                    return await networkingSessionDelegate.retry(self, delay: delay)

                case .doNotRetry:
                    repeatCount.reset()
                    return serializedResult
            }
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
