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

    public func start(request requestConvertible: URLRequestConvertible) -> NetworkingSessionDataTask {
        let networkRouteDataTask = NetworkingSessionDataTask(requestConvertible: requestConvertible,
                                                             requestRetrier: requestRetrier,
                                                             delegate: self)
        start(networkingSessionDataTask: networkRouteDataTask)
        return networkRouteDataTask
    }
}

extension NetworkingSession {

    private func start(networkingSessionDataTask: NetworkingSessionDataTask) {

        guard let urlRequest = networkingSessionDataTask.request else {
            DispatchQueue.global(qos: .userInteractive).async {
                networkingSessionDataTask.executeResponseSerializers(with: DataTaskResponseContainer(response: nil,
                                                                                                     data: nil,
                                                                                                     error: nil))
            }
            return
        }

        guard let requestAdapter = requestAdapter else {
            execute(urlRequest, accompaniedWith: networkingSessionDataTask)
            return
        }

        requestAdapter.adapt(urlRequest: urlRequest, for: session) { [weak self] adaptedUrlRequestResult in
            guard let self = self else { return }

            switch adaptedUrlRequestResult {
                case .success(let adaptedUrlRequest):
                    self.execute(adaptedUrlRequest, accompaniedWith: networkingSessionDataTask)

                case .failure(let error):
                    DispatchQueue.global(qos: .userInteractive).async {
                        networkingSessionDataTask.executeResponseSerializers(with: DataTaskResponseContainer(response: nil,
                                                                                                             data: nil,
                                                                                                             error: error))
                    }
            }
        }
    }

    private func execute(_ urlRequest: URLRequest, accompaniedWith networkingSessionDataTask: NetworkingSessionDataTask) {

        let dataTask = session.dataTask(with: urlRequest) { (responseData, response, error) in
            networkingSessionDataTask.executeResponseSerializers(with: DataTaskResponseContainer(response: response as? HTTPURLResponse,
                                                                                                 data: responseData,
                                                                                                 error: error))
        }

        networkingSessionDataTask.dataTask = dataTask
        dataTask.resume()
    }
}

extension NetworkingSession: NetworkingSessionDataTaskDelegate {
    internal func restart(networkingSessionDataTask: NetworkingSessionDataTask) {
        start(networkingSessionDataTask: networkingSessionDataTask)
    }
}
