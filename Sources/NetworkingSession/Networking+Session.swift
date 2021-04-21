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

    public func createDataTask(from requestConvertible: URLRequestConvertible) -> NetworkingSessionDataTask {
        return NetworkingSessionDataTask(requestConvertible: requestConvertible,
                                         requestAdapter: requestAdapter,
                                         requestRetrier: requestRetrier,
                                         delegate: self)
    }

    private func execute(_ urlRequest: URLRequest, accompaniedWith networkingSessionDataTask: NetworkingSessionDataTask) {

        let dataTask = session.dataTask(with: urlRequest) { (responseData, response, error) in
            networkingSessionDataTask.executeResponseSerializers(with: NetworkingRawResponse(urlRequest: urlRequest,
                                                                                             urlResponse: response as? HTTPURLResponse,
                                                                                             data: responseData,
                                                                                             error: error))
        }

        networkingSessionDataTask.dataTask = dataTask
        dataTask.resume()
    }
}

extension NetworkingSession: NetworkingSessionDataTaskDelegate {
    internal func networkingSessionDataTaskIsReadyToExecute(urlRequest: URLRequest, accompaniedWith networkingSessionDataTask: NetworkingSessionDataTask) {
        execute(urlRequest, accompaniedWith: networkingSessionDataTask)
    }
}
