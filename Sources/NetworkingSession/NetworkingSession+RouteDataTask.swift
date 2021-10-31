//
//  File.swift
//  
//
//  Created by Dan_Koza on 2/8/21.
//

import Foundation

internal protocol NetworkingRouteDataTaskDelegate: AnyObject {
    func retry<Route: NetworkingRoute>(routeDataTask: NetworkingSession.RouteDataTask<Route>) async -> Result<Route.ResponseSerializer.SerializedObject, Error>
}

public extension NetworkingSession {
    /// `RouteDataTask`  a wrapper class for `URLSessionDataTask`. In addition, a `RouteDataTask` will automatically serialize the `URLSessionDataTask.RawResponse` into the `NetworkingRoute.ResponseSerializer.SerializedObject`. Further, a `RouteDataTask` can also utilize a ``NetworkingRequestAdapter`` or ``NetworkingRequestRetrier``.
    class RouteDataTask<Route: NetworkingRoute> {

        private let route: Route
        private var retryTask: Task<Result<Route.ResponseSerializer.SerializedObject, Error>, Never>?

        private var currentRequest: URLRequest?
//        internal var urlSessionDataTask: URLSessionDataTask? = nil
        private var retryCount = 0
        private weak var requestAdapter: NetworkingRequestAdapter?
        private weak var requestRetrier: NetworkingRequestRetrier?
        private weak var delegate: NetworkingRouteDataTaskDelegate?

//        /// Cancels the HTTPRequest
//        public func cancel() {
//            urlSessionDataTask?.cancel()
//        }

        internal init(route: Route,
                      requestAdapter: NetworkingRequestAdapter?,
                      requestRetrier: NetworkingRequestRetrier?,
                      routeDataTaskDelegate: NetworkingRouteDataTaskDelegate) {
            self.route = route
            self.delegate = routeDataTaskDelegate
            self.requestAdapter = requestAdapter
            self.requestRetrier = requestRetrier
        }

        internal var urlRequest: URLRequest {
            get throws {
                let urlRequest = try currentRequest ?? route.urlRequest
                currentRequest = urlRequest
                let adaptedUrlRequest = try requestAdapter?.adapt(urlRequest: urlRequest)
                currentRequest = adaptedUrlRequest ?? urlRequest
                return adaptedUrlRequest ?? urlRequest
            }
        }

        internal func executeResponseSerializer(with rawResponse: URLSessionDataTask.RawResponse) async -> Result<Route.ResponseSerializer.SerializedObject, Error> {
            let serializedResult = route.responseSerializer.serialize(response: rawResponse)
            //Check if the response contains an error, if not, trigger the completionHandler.
            guard
                let error = rawResponse.error ?? serializedResult.error,
                let retrier = requestRetrier,
                let urlRequest = rawResponse.urlRequest ?? currentRequest,
                let delegate = delegate
            else {
                return serializedResult
            }

            if let retryTask = retryTask {
                return await retryTask.value
            }
            else {
                let retryTask = Task<Result<Route.ResponseSerializer.SerializedObject, Error>, Never> {
                    defer { self.retryTask = nil }
                    //If there is an error, we now ask the retrier if the failed request should be restarted or not
                    let retryResult = await retrier.retry(urlRequest: urlRequest,
                                                          dueTo: error,
                                                          urlResponse: rawResponse.urlResponse ?? HTTPURLResponse(),
                                                          retryCount: retryCount)

                    switch retryResult {
                        case .doNotRetry:

                            return serializedResult

                        case .retry:
                            self.retryCount += 1
                            return await delegate.retry(routeDataTask: self)
                    }
                }
                self.retryTask = retryTask
                return await retryTask.value
            }
        }
    }
}

private extension Result {
    var error: Error? {
        guard case let .failure(error) = self else { return nil }
        return error
    }
}
