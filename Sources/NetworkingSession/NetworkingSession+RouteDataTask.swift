//
//  File.swift
//  
//
//  Created by Dan_Koza on 2/8/21.
//

import Foundation

extension NetworkingSession {
    internal class RouteDataTask<Route: NetworkingRoute> {

        typealias RawRequestResponse = (request: URLRequest?, responseData: Data?, response: HTTPURLResponse?, error: Error?)

        private let route: Route
        private var dataTask: URLSessionDataTask?
        private var sessionRetryCount = 0
        private var responseRetryCount = 0
        private weak var networkingSessionDelegate: NetworkingSessionDelegate?

        init(route: Route,
             networkingSessionDelegate: NetworkingSessionDelegate) {
            self.route = route
            self.networkingSessionDelegate = networkingSessionDelegate
        }

        func executeRoute(urlSession: URLSessionProtocol,
                          requestAdapter: NetworkingRequestAdapter?) async -> RawRequestResponse {
            do {
                let urlRequestToRun = try await getUrlRequest(requestAdapter: requestAdapter)
                let rawRouteResponse = try await withThrowingTaskGroup(of: RawRequestResponse.self, body: { taskGroup -> RawRequestResponse in
                    taskGroup.addTask {
                        let routeResponse: RawRequestResponse = try await withCheckedThrowingContinuation { continuation in
                            self.dataTask = urlSession.dataTask(with: urlRequestToRun) { data, response, error in
                                continuation.resume(returning: (urlRequestToRun,
                                                                data,
                                                                response as? HTTPURLResponse,
                                                                error))
                            }
                            Task.isCancelled ? self.dataTask?.cancel() : self.dataTask?.resume()
                        }
                        return routeResponse
                    }

                    if let timeout = route.timeout {
                        taskGroup.addTask {
                            try? await Task.sleep(nanoseconds: UInt64(timeout) * 1_000_000_000)
                            return (nil, nil, nil, URLError(.timedOut, userInfo: ["Reason": "\(type(of: self.route)) timed out after \(timeout) seconds."]))
                        }
                    }

                    guard let rawRouteResponse = try await taskGroup.next() else {
                        throw URLError(.unknown, userInfo: ["Reason": "PopNetworking internal error, \(type(of: self.route)) failed to complete."])
                    }
                    taskGroup.cancelAll()
                    self.dataTask?.cancel()
                    return rawRouteResponse
                })
                return rawRouteResponse
            }
            catch {
                return (nil, nil, nil, error)
            }
        }

        func executeResponseSerializer(responseData: Data?,
                                       response: HTTPURLResponse?,
                                       responseError: Error?) -> Result<Route.ResponseSerializer.SerializedObject, Error> {
            return route.responseSerializer.serialize(responseData: responseData,
                                                      urlResponse: response,
                                                      responseError: responseError)
        }

        func executeSessionRetrier(retrier: NetworkingRequestRetrier?,
                                   serializedResult: Result<Route.ResponseSerializer.SerializedObject, Error>,
                                   request: URLRequest?,
                                   response: HTTPURLResponse?,
                                   responseError: Error?) async throws -> Result<Route.ResponseSerializer.SerializedObject, Error> {
            guard
                let retrier = retrier,
                let networkingSessionDelegate = networkingSessionDelegate,
                let error = responseError ?? serializedResult.error
            else {
                return serializedResult
            }

            switch await retrier.retry(urlRequest: request,
                                       dueTo: error,
                                       urlResponse: response,
                                       retryCount: sessionRetryCount) {
                case .retry:
                    incrementSessionRetryCount()
                    return try await networkingSessionDelegate.retry(self)

                case .retryWithDelay(let delay):
                    try? await Task.sleep(nanoseconds: UInt64(delay) * 1_000_000_000)
                    incrementSessionRetryCount()
                    return try await networkingSessionDelegate.retry(self)

                case .doNotRetry:
                    return serializedResult
            }
        }

        func executeRouteRetrier(serializedResult: Result<Route.ResponseSerializer.SerializedObject, Error>,
                                 response: HTTPURLResponse?) async throws -> Result<Route.ResponseSerializer.SerializedObject, Error> {
            guard
                let routeRetrier = route.retrier,
                let networkingSessionDelegate = networkingSessionDelegate
            else {
                return serializedResult
            }

            switch try await routeRetrier(serializedResult, response, responseRetryCount) {
                case .retry:
                    incrementResponseRetryCount()
                    return try await networkingSessionDelegate.retry(self)

                case .retryWithDelay(let delay):
                    try? await Task.sleep(nanoseconds: UInt64(delay) * 1_000_000_000)
                    incrementResponseRetryCount()
                    return try await networkingSessionDelegate.retry(self)

                case .doNotRetry:
                    return serializedResult
            }
        }
    }
}

private extension NetworkingSession.RouteDataTask {

    func getUrlRequest(requestAdapter: NetworkingRequestAdapter?) async throws -> URLRequest {
        let urlRequest = try route.urlRequest
        let adaptedUrlRequest = try await requestAdapter?.adapt(urlRequest: urlRequest)
        return adaptedUrlRequest ?? urlRequest
    }

    func incrementSessionRetryCount() {
        sessionRetryCount += 1
    }

    func incrementResponseRetryCount() {
        responseRetryCount += 1
    }
}

private extension Result {
    var error: Error? {
        guard case let .failure(error) = self else { return nil }
        return error
    }
}
