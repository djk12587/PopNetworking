//
//  File.swift
//  
//
//  Created by Dan_Koza on 12/1/21.
//

import Foundation

/// A `Route` is a basic implementation of a ``NetworkingRoute``. Use `Route` as a quick and dirty way to get an endpoint up and running
///
/// ```
/// //Example usage
/// Route(baseUrl: "https://www.baseUrl.com",
///       responseSerializer: NetworkingResponseSerializers.DataResponseSerializer()).request { result in
///     switch result {
///         case .success(let responseData):
///             print(responseData)
///         case .failure(let error):
///             print(error)
///     }
/// }
/// ```
public struct Route<ResponseSerializer: NetworkingResponseSerializer>: NetworkingRoute {

    public var baseUrl: String
    public var path: String
    public var method: NetworkingRouteHttpMethod
    public var headers: NetworkingRouteHttpHeaders?
    public var parameterEncoding: NetworkingRequestParameterEncoding?
    public var session: NetworkingSession
    public var responseValidator: NetworkingResponseValidator?
    public var responseSerializer: ResponseSerializer
    public var mockSerializedResult: Result<ResponseSerializer.SerializedObject, Error>?
    public var timeoutInterval: TimeInterval?
    public var repeater: Repeater?

    public init(baseUrl: String,
                path: String = "",
                method: NetworkingRouteHttpMethod = .get,
                headers: NetworkingRouteHttpHeaders? = nil,
                parameterEncoding: NetworkingRequestParameterEncoding? = nil,
                session: NetworkingSession = .shared,
                responseValidator: NetworkingResponseValidator? = nil,
                responseSerializer: ResponseSerializer,
                mockSerializedResult: Result<ResponseSerializer.SerializedObject, Error>? = nil,
                timeoutInterval: TimeInterval? = nil,
                repeater: Repeater? = nil) {
        self.baseUrl = baseUrl
        self.path = path
        self.method = method
        self.headers = headers
        self.parameterEncoding = parameterEncoding
        self.session = session
        self.responseValidator = responseValidator
        self.responseSerializer = responseSerializer
        self.mockSerializedResult = mockSerializedResult
        self.timeoutInterval = timeoutInterval
        self.repeater = repeater
    }
}
