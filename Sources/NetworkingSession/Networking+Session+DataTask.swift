//
//  File.swift
//  
//
//  Created by Dan_Koza on 2/8/21.
//

import Foundation

internal protocol NetworkingSessionDataTaskDelegate: AnyObject {
    func retry<Route: NetworkingRoute>(networkingSessionDataTask: NetworkingSessionDataTask<Route>,
                                       runCompletionHandlerOn queue: DispatchQueue,
                                       completionHandler: @escaping (Result<Route.ResponseSerializer.SerializedObject, Error>) -> Void)
}

public class NetworkingSessionDataTask<Route: NetworkingRoute>: Cancellable {

    private let route: Route
    private var currentRequest: URLRequest?

    internal var dataTask: URLSessionDataTask? = nil
    private(set) var wasCancelled = false

    private(set) var retryCount = 0
    private weak var requestAdapter: NetworkingRequestAdapter?
    private weak var requestRetrier: NetworkingRequestRetrier?
    private weak var delegate: NetworkingSessionDataTaskDelegate?

    public var cancellableTask: Cancellable {
        return self
    }

    public func cancel() {
        wasCancelled = true
        dataTask?.cancel()
    }

    internal init(route: Route,
                  requestAdapter: NetworkingRequestAdapter?,
                  requestRetrier: NetworkingRequestRetrier?,
                  delegate: NetworkingSessionDataTaskDelegate) {
        self.route = route
        self.delegate = delegate
        self.requestAdapter = requestAdapter
        self.requestRetrier = requestRetrier
    }

    internal func createUrlRequest() throws -> URLRequest {
        let urlRequest = try currentRequest ?? route.asUrlRequest()
        currentRequest = urlRequest
        let adaptedUrlRequest = try requestAdapter?.adapt(urlRequest: urlRequest)
        currentRequest = adaptedUrlRequest ?? urlRequest
        return adaptedUrlRequest ?? urlRequest
    }

    internal func executeResponseSerializer(with rawResponse: NetworkingRawResponse,
                                            runCompletionHandlerOn queue: DispatchQueue,
                                            completionHandler: @escaping (Result<Route.ResponseSerializer.SerializedObject, Error>) -> Void) {
        let serializedResult = route.responseSerializer.serialize(response: rawResponse)
        //Check if the response contains an error, if not, trigger the completionHandler.
        guard
            let error = rawResponse.error ?? serializedResult.error,
            let retrier = self.requestRetrier,
            let urlRequest = rawResponse.urlRequest ?? currentRequest
        else {
            queue.async { completionHandler(serializedResult) }
            return
        }

        //If there is an error, we now ask the retrier if the failed request should be restarted or not
        retrier.retry(urlRequest: urlRequest,
                      dueTo: error,
                      urlResponse: rawResponse.urlResponse ?? HTTPURLResponse(),
                      retryCount: self.retryCount) { retrierResult in

            switch retrierResult {
                case .doNotRetry:
                    queue.async { completionHandler(serializedResult) }

                case .retry:
                    self.retryCount += 1
                    self.delegate?.retry(networkingSessionDataTask: self,
                                         runCompletionHandlerOn: queue,
                                         completionHandler: completionHandler)
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
