//
//  File.swift
//  
//
//  Created by Dan_Koza on 2/8/21.
//

import Foundation

public extension NetworkingSession {
    internal class RouteDataTask<Route: NetworkingRoute> {

        private let route: Route
        private var currentRequest: URLRequest?
        private var dataTask: URLSessionDataTask?
        private weak var requestAdapter: NetworkingRequestAdapter?
        private(set) var retryCount = 0

        private var urlRequest: URLRequest {
            get throws {
                let urlRequest = try currentRequest ?? route.urlRequest
                currentRequest = urlRequest
                let adaptedUrlRequest = try requestAdapter?.adapt(urlRequest: urlRequest)
                currentRequest = adaptedUrlRequest ?? urlRequest
                return adaptedUrlRequest ?? urlRequest
            }
        }

        internal init(route: Route, requestAdapter: NetworkingRequestAdapter?) {
            self.route = route
            self.requestAdapter = requestAdapter
        }

        internal func response(urlSession: URLSession) async -> (URLRequest?, Data?, HTTPURLResponse?, Error?) {
            await withCheckedContinuation { continuation in
                do {
                    let urlRequestToSend = try urlRequest
                    dataTask = urlSession.dataTask(with: urlRequestToSend) { data, response, error in
                        continuation.resume(returning: (urlRequestToSend,
                                                        data,
                                                        response as? HTTPURLResponse,
                                                        error))
                    }
                    Task.isCancelled ? dataTask?.cancel() : dataTask?.resume()
                }
                catch {
                    continuation.resume(returning: (nil, nil, nil, error))
                }
            }
        }

        internal func executeResponseSerializer(with response: (data: Data?, urlResponse: HTTPURLResponse?, error: Error?)) -> Result<Route.ResponseSerializer.SerializedObject, Error> {
            return route.responseSerializer.serialize(response: response)
        }

        internal func incrementRetryCount() {
            retryCount += 1
        }
    }
}
