//
//  Networking+Session.swift
//  PopNetworking
//
//  Created by Daniel Koza on 1/8/21.
//  Copyright © 2021 Daniel Koza. All rights reserved.
//

import Foundation

// MARK: - NetworkingSession

public extension NetworkingSession {
    /// The shared singleton `NetworkingSession` object.
    ///
    /// For basic requests, the `NetworkingSession` class provides a shared singleton session object that gives you a reasonable default behavior for creating tasks.
    ///
    /// Unlike the other session types, you don’t create the shared session; you merely access it by using this property directly. As a result, you don’t provide a `URLSession` object, `NetworkingRequestAdapter`, or `NetworkingRequestRetrier`.
    static let shared = NetworkingSession()
}

public class NetworkingSession {

    private let session: URLSession
    private let requestAdapter: NetworkingRequestAdapter?
    private let requestRetrier: NetworkingRequestRetrier?

    public init(session: URLSession = URLSession(configuration: .default),
                requestAdapter: NetworkingRequestAdapter? = nil,
                requestRetrier: NetworkingRequestRetrier? = nil) {
        self.session = session
        self.requestAdapter = requestAdapter
        self.requestRetrier = requestRetrier
    }

    public func execute<Route: NetworkingRoute>(route: Route,
                                                runCompletionHandlerOn queue: DispatchQueue = .main,
                                                completionHandler: @escaping (Result<Route.ResponseSerializer.SerializedObject, Error>) -> Void) -> Cancellable {
        if let mockResponse = route.mockResponse {
            queue.async { completionHandler(mockResponse) }
            return MockedCancellable()
        }
        else {
            let dataTask = NetworkingSessionDataTask(route: route,
                                                     requestAdapter: requestAdapter,
                                                     requestRetrier: requestRetrier,
                                                     delegate: self)
            execute(dataTask, runCompletionHandlerOn: queue, completionHandler: completionHandler)
            return dataTask.cancellableTask
        }
    }

    private func execute<Route: NetworkingRoute>(_ dataTask: NetworkingSessionDataTask<Route>,
                                                 runCompletionHandlerOn queue: DispatchQueue,
                                                 completionHandler: @escaping (Result<Route.ResponseSerializer.SerializedObject, Error>) -> Void) {
        do {
            let urlRequest = try dataTask.createUrlRequest()
            let urlSessionTask = session.dataTask(with: urlRequest) { (responseData, response, error) in
                dataTask.executeResponseSerializer(with: NetworkingRawResponse(urlRequest: urlRequest,
                                                                               urlResponse: response as? HTTPURLResponse,
                                                                               data: responseData,
                                                                               error: error),
                                                   runCompletionHandlerOn: queue,
                                                   completionHandler: completionHandler)
            }

            dataTask.dataTask = urlSessionTask
            urlSessionTask.resume()

            if dataTask.wasCancelled {
                dataTask.cancel()
            }
        } catch {
            dataTask.executeResponseSerializer(with: NetworkingRawResponse(urlRequest: nil, urlResponse: nil, data: nil, error: error),
                                               runCompletionHandlerOn: queue,
                                               completionHandler: completionHandler)
        }
    }
}

extension NetworkingSession: NetworkingSessionDataTaskDelegate {
    internal func retry<Route: NetworkingRoute>(networkingSessionDataTask: NetworkingSessionDataTask<Route>,
                                                runCompletionHandlerOn queue: DispatchQueue,
                                                completionHandler: @escaping (Result<Route.ResponseSerializer.SerializedObject, Error>) -> Void) {
        execute(networkingSessionDataTask, runCompletionHandlerOn: queue, completionHandler: completionHandler)
    }
}
