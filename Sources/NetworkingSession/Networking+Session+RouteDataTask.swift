//
//  File.swift
//  
//
//  Created by Dan_Koza on 2/8/21.
//

import Foundation

internal protocol NetworkingRouteDataTaskDelegate: AnyObject {
    func retry<Route: NetworkingRoute>(networkingSessionDataTask: NetworkingSession.RouteDataTask<Route>)
}

extension NetworkingSession {
    public class RouteDataTask<Route: NetworkingRoute>: Cancellable {

        deinit {
            print("DEINIT!!!!@#")
        }

        private let route: Route
        private let completionHandlerQueue: DispatchQueue
        private let routeCompletionHandler: (Result<Route.ResponseSerializer.SerializedObject, Error>) -> Void

        private var currentRequest: URLRequest?
        internal var urlSessionDataTask: URLSessionDataTask? = nil
        private var retryCount = 0
        private weak var requestAdapter: NetworkingRequestAdapter?
        private weak var requestRetrier: NetworkingRequestRetrier?
        private weak var delegate: NetworkingRouteDataTaskDelegate?

        public func cancel() {
            urlSessionDataTask?.cancel()
        }

        internal init(route: Route,
                      requestAdapter: NetworkingRequestAdapter?,
                      requestRetrier: NetworkingRequestRetrier?,
                      routeDataTaskDelegate: NetworkingRouteDataTaskDelegate,
                      completionHandlerQueue: DispatchQueue,
                      routeCompletionHandler: @escaping (Result<Route.ResponseSerializer.SerializedObject, Error>) -> Void) {
            self.route = route
            self.delegate = routeDataTaskDelegate
            self.requestAdapter = requestAdapter
            self.requestRetrier = requestRetrier
            self.completionHandlerQueue = completionHandlerQueue
            self.routeCompletionHandler = routeCompletionHandler
        }

        internal var urlRequest: URLRequest {
            get throws {
                let urlRequest = try currentRequest ?? route.asUrlRequest()
                currentRequest = urlRequest
                let adaptedUrlRequest = try requestAdapter?.adapt(urlRequest: urlRequest)
                currentRequest = adaptedUrlRequest ?? urlRequest
                return adaptedUrlRequest ?? urlRequest
            }
        }

        internal func executeResponseSerializer(with rawResponse: NetworkingRawResponse) {
            let serializedResult = route.responseSerializer.serialize(response: rawResponse)
            //Check if the response contains an error, if not, trigger the completionHandler.
            guard
                let error = rawResponse.error ?? serializedResult.error,
                let retrier = self.requestRetrier,
                let urlRequest = rawResponse.urlRequest ?? currentRequest
            else {
                completionHandlerQueue.async { self.routeCompletionHandler(serializedResult) }
                return
            }

            //If there is an error, we now ask the retrier if the failed request should be restarted or not
            retrier.retry(urlRequest: urlRequest,
                          dueTo: error,
                          urlResponse: rawResponse.urlResponse ?? HTTPURLResponse(),
                          retryCount: self.retryCount) { retrierResult in

                switch retrierResult {
                    case .doNotRetry:
                        self.completionHandlerQueue.async { self.routeCompletionHandler(serializedResult) }

                    case .retry:
                        self.retryCount += 1
                        self.delegate?.retry(networkingSessionDataTask: self)
                }
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
