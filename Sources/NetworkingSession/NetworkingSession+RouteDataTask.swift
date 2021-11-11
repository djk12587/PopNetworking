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
        private(set) var retryCount = 0

        init(route: Route) {
            self.route = route
        }

        private func getUrlRequest(requestAdapter: NetworkingRequestAdapter?) async throws -> URLRequest {
            let urlRequest = try currentRequest ?? route.urlRequest
            currentRequest = urlRequest
            let adaptedUrlRequest = try await requestAdapter?.adapt(urlRequest: urlRequest)
            currentRequest = adaptedUrlRequest ?? urlRequest
            return adaptedUrlRequest ?? urlRequest
        }

        func dataResponse(urlSession: URLSessionProtocol, requestAdapter: NetworkingRequestAdapter?) async -> (URLRequest?, Data?, HTTPURLResponse?, Error?) {
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

        func executeResponseSerializer(with response: (data: Data?, urlResponse: HTTPURLResponse?, error: Error?)) -> Result<Route.ResponseSerializer.SerializedObject, Error> {
            return route.responseSerializer.serialize(responseData: response.data, urlResponse: response.urlResponse, responseError: response.error)
        }

        func incrementRetryCount() {
            retryCount += 1
        }
    }
}
