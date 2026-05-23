//
//  File.swift
//  
//
//  Created by Dan_Koza on 12/1/21.
//

import Foundation

/// A `ResponseRoute` is a basic implementation of a ``NetworkingResponseRoute``. Use `ResponseRoute` as a way to explore ``PopNetworking``'s functionality.
///
/// ```swift
/// //Example usage
/// ResponseRoute(baseUrl: "https://www.baseUrl.com",
///       serializer: NetworkingSerializers.Response.Data()).request { result in
///     switch result {
///         case .success(let responseData):
///             print(responseData)
///         case .failure(let error):
///             print(error)
///     }
/// }
/// ```
public struct ResponseRoute<Serializer: NetworkingResponseSerializer>: NetworkingResponseRoute {

    public var baseUrl: String
    public var path: String
    public var method: NetworkingRouteHttpMethod
    public var headers: NetworkingRouteHttpHeaders?
    public var parameterEncoding: NetworkingRouteParameterEncoding?
    public var session: NetworkingSessionProtocol
    public var serializer: Serializer
    public var mockSerializedResult: Result<Serializer.SerializedObject, Error>?
    public var timeoutInterval: TimeInterval?
    public var adapter: NetworkingAdapter?
    public var retrier: NetworkingRetrier?
    public var interceptor: NetworkingInterceptor?
    public var observers: [NetworkingTransportObserver]
    public var repeater: Repeater?

    public init(baseUrl: String,
                path: String = "",
                method: NetworkingRouteHttpMethod = .get,
                headers: NetworkingRouteHttpHeaders? = nil,
                parameterEncoding: NetworkingRouteParameterEncoding? = nil,
                session: NetworkingSessionProtocol = NetworkingSession.shared,
                serializer: Serializer,
                mockSerializedResult: Result<Serializer.SerializedObject, Error>? = nil,
                timeoutInterval: TimeInterval? = nil,
                adapter: NetworkingAdapter? = nil,
                retrier: NetworkingRetrier? = nil,
                interceptor: NetworkingInterceptor? = nil,
                observers: [NetworkingTransportObserver] = [],
                repeater: Repeater? = nil) {
        self.baseUrl = baseUrl
        self.path = path
        self.method = method
        self.headers = headers
        self.parameterEncoding = parameterEncoding
        self.session = session
        self.serializer = serializer
        self.mockSerializedResult = mockSerializedResult
        self.timeoutInterval = timeoutInterval
        self.adapter = adapter
        self.retrier = retrier
        self.interceptor = interceptor
        self.observers = observers
        self.repeater = repeater
    }
}
