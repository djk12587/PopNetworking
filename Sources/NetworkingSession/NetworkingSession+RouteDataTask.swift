//
//  File.swift
//  
//
//  Created by Dan_Koza on 2/8/21.
//

import Foundation

extension NetworkingSession {
    internal class RouteDataTask<Route: NetworkingRoute> {

        private let route: Route
        private var currentRequest: URLRequest?
        private var dataTask: URLSessionDataTask?
        private var sessionRetryCount = 0
        private var responseRetryCount = 0
        private weak var networkingSessionDelegate: NetworkingSessionDelegate?

        init(route: Route, networkingSessionDelegate: NetworkingSessionDelegate) {
            self.route = route
            self.networkingSessionDelegate = networkingSessionDelegate
        }

        func executeRoute(urlSession: URLSessionProtocol,
                          requestAdapter: NetworkingRequestAdapter?) async -> (URLRequest?, Data?, HTTPURLResponse?, Error?) {
            do {
                let urlRequestToRun = try await getUrlRequest(requestAdapter: requestAdapter)
                return await withCheckedContinuation { continuation in
                    dataTask = urlSession.dataTask(with: urlRequestToRun) { data, response, error in
                        continuation.resume(returning: (urlRequestToRun,
                                                        data,
                                                        response as? HTTPURLResponse,
                                                        error))
                    }
                    Task.isCancelled ? dataTask?.cancel() : dataTask?.resume()
                }
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
                    try await Task.sleep(nanoseconds: UInt64(delay) * 1_000_000_000)
                    incrementSessionRetryCount()
                    return try await networkingSessionDelegate.retry(self)

                case .doNotRetry:
                    return serializedResult
            }
        }

        func executeResponseRetrier(serializedResult: Result<Route.ResponseSerializer.SerializedObject, Error>,
                                    response: HTTPURLResponse?) async throws -> Result<Route.ResponseSerializer.SerializedObject, Error> {
            guard
                let routeResponseRetrier = route.responseRetrier,
                let networkingSessionDelegate = networkingSessionDelegate
            else {
                return serializedResult
            }

            switch try await routeResponseRetrier(serializedResult, response, responseRetryCount) {
                case .retryWithDelay(let delay):
                    try await Task.sleep(nanoseconds: UInt64(delay) * 1_000_000_000)
                    incrementResponseRetryCount()
                    return try await networkingSessionDelegate.retry(self)

                case .retry:
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
        let urlRequest = try currentRequest ?? route.urlRequest
        currentRequest = urlRequest
        let adaptedUrlRequest = try await requestAdapter?.adapt(urlRequest: urlRequest)
        currentRequest = adaptedUrlRequest ?? urlRequest
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
