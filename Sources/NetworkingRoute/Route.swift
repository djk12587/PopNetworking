//
//  File.swift
//  
//
//  Created by Dan_Koza on 12/1/21.
//

import Foundation

public struct Route<ResponseSerializer: NetworkingResponseSerializer>: NetworkingRoute {

    public var baseUrl: String
    public var path: String
    public var method: NetworkingRouteHttpMethod
    public var headers: NetworkingRouteHttpHeaders?
    public var parameterEncoding: NetworkingRequestParameterEncoding
    public var session: NetworkingSession
    public var responseSerializer: ResponseSerializer
    public var responseRetrier: ResponseRetrier?

    public init(baseUrl: String,
                path: String = "",
                method: NetworkingRouteHttpMethod = .get,
                headers: NetworkingRouteHttpHeaders? = nil,
                parameterEncoding: NetworkingRequestParameterEncoding = .url(params: nil),
                session: NetworkingSession = NetworkingSession(urlSession: URLSession(configuration: .default)),
                responseSerializer: ResponseSerializer,
                responseRetrier: @escaping ResponseRetrier) {
        self.baseUrl = baseUrl
        self.path = path
        self.method = method
        self.headers = headers
        self.parameterEncoding = parameterEncoding
        self.session = session
        self.responseSerializer = responseSerializer
        self.responseRetrier = responseRetrier
    }
}
