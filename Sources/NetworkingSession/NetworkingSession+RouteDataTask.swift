//
//  File.swift
//  
//
//  Created by Dan_Koza on 2/8/21.
//

import Foundation

//internal protocol NetworkingRouteDataTaskDelegate: AnyObject {
//    func retry<Route: NetworkingRoute>(routeDataTask: NetworkingSession.RouteDataTask<Route>) async -> Result<Route.ResponseSerializer.SerializedObject, Error>
//}

public extension NetworkingSession {
    /// `RouteDataTask`  a wrapper class for `URLSessionDataTask`. In addition, a `RouteDataTask` will automatically serialize the `URLSessionDataTask.RawResponse` into the `NetworkingRoute.ResponseSerializer.SerializedObject`. Further, a `RouteDataTask` can also utilize a ``NetworkingRequestAdapter`` or ``NetworkingRequestRetrier``.
    class RouteDataTask<Route: NetworkingRoute> {

        private let route: Route
        private var currentRequest: URLRequest?
        private weak var requestAdapter: NetworkingRequestAdapter?
        private(set) var retryCount = 0

        internal init(route: Route, requestAdapter: NetworkingRequestAdapter?) {
            self.route = route
            self.requestAdapter = requestAdapter
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

        internal func executeResponseSerializer(with rawResponse: URLSessionDataTask.RawResponse) -> Result<Route.ResponseSerializer.SerializedObject, Error> {
            return route.responseSerializer.serialize(response: rawResponse)
        }

        internal func incrementRetryCount() {
            retryCount += 1
        }
    }
}
