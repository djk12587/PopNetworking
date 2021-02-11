//
//  Networking+Session.swift
//  CrustyNetworking
//
//  Created by Daniel Koza on 1/8/21.
//  Copyright © 2021 Daniel Koza. All rights reserved.
//

import Foundation

// MARK: - NetworkingSession

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

        guard var urlRequest = networkingSessionDataTask.request else {
            DispatchQueue.global(qos: .userInteractive).async {
                networkingSessionDataTask.executeResponseSerializers(with: DataTaskResponseContainer(response: nil,
                                                                                                     data: nil,
                                                                                                     error: nil))
            }
            return
        }

        if let adapatedRequest = requestAdapter?.adapt(urlRequest: urlRequest, for: session) {
            urlRequest = adapatedRequest
        }

        let dataTask = session.dataTask(with: urlRequest) { (responseData, response, error) in
            let dataTaskResponseContainer = DataTaskResponseContainer(response: response as? HTTPURLResponse,
                                                                      data: responseData,
                                                                      error: error)
            networkingSessionDataTask.executeResponseSerializers(with: dataTaskResponseContainer)
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
