//
//  File.swift
//  
//
//  Created by Dan_Koza on 2/8/21.
//

import Foundation

extension NetworkingSession {
    internal actor RouteDataTask<Route: NetworkingRoute> {

        typealias RawRequestResponse = (request: URLRequest?,
                                        response: HTTPURLResponse?,
                                        result: Result<Data, Error>)

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
                let urlRequest = try await getUrlRequest(requestAdapter: requestAdapter)
                let (_, response, result) = try await execute(urlRequest, on: urlSession)
                return (urlRequest, response, result)
            }
            catch {
                return (nil, nil, .failure(error))
            }
        }

        func executeResponseSerializer(result: Result<Data, Error>,
                                       response: HTTPURLResponse?) -> Result<Route.ResponseSerializer.SerializedObject, Error> {
            return route.responseSerializer.serialize(result: result, urlResponse: response)
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
                    return try await networkingSessionDelegate.retry(self, delay: nil)

                case .retryWithDelay(let delay):
                    incrementSessionRetryCount()
                    return try await networkingSessionDelegate.retry(self, delay: delay)

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
                    return try await networkingSessionDelegate.retry(self, delay: nil)

                case .retryWithDelay(let delay):
                    incrementResponseRetryCount()
                    return try await networkingSessionDelegate.retry(self, delay: delay)

                case .doNotRetry:
                    return serializedResult
            }
        }
    }
}

private extension NetworkingSession.RouteDataTask {

    func execute(_ urlRequest: URLRequest, on urlSession: URLSessionProtocol) async throws -> RawRequestResponse {
        return try await withThrowingTaskGroup(of: RawRequestResponse.self, body: { taskGroup -> RawRequestResponse in

            taskGroup.addTask {
                do {
                    let (data, response) = try await urlSession.data(for: urlRequest)
                    return (urlRequest, response as? HTTPURLResponse, .success(data))
                }
                catch {
                    return (urlRequest, nil, .failure(error))
                }
            }

            if let timeout = route.timeout {
                taskGroup.addTask {
                    try? await Task.sleep(nanoseconds: UInt64(timeout) * 1_000_000_000)
                    return (urlRequest, nil, .failure(URLError(.timedOut, userInfo: ["Reason": "\(type(of: self.route)) timed out after \(timeout) seconds."])))
                }
            }

            guard let rawRequestResponse = try await taskGroup.next() else {
                throw URLError(.unknown, userInfo: ["Reason": "PopNetworking internal error, \(type(of: self.route)) failed to complete."])
            }
            taskGroup.cancelAll()
            return rawRequestResponse
        })
    }

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

internal extension Result {
    var error: Error? {
        guard case let .failure(error) = self else { return nil }
        return error
    }
}
