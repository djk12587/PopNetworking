//
//  StreamRoute.swift
//  PopNetworking
//

import Foundation

/// A concrete implementation of ``NetworkingStreamRoute`` for one-off streaming requests
/// that don't warrant a dedicated `struct` per endpoint. Mirrors ``ResponseRoute``.
///
/// Example:
/// ```swift
/// let chatStream = StreamRoute(
///     baseUrl: "https://api.example.com",
///     path: "chat",
///     method: .post,
///     parameterEncoding: .json(params: ["prompt": "hello"]),
///     serializer: NetworkingSerializers.Stream.SSE()
/// )
///
/// for try await event in try await chatStream.stream {
///     print(event.data)
/// }
/// ```
@available(iOS 15, macOS 12, tvOS 15, watchOS 8, visionOS 1, *)
public struct StreamRoute<Serializer: NetworkingStreamSerializer>: NetworkingStreamRoute {

    public var baseUrl: String
    public var path: String
    public var method: NetworkingRouteHttpMethod
    public var headers: NetworkingRouteHttpHeaders?
    public var parameterEncoding: NetworkingRouteParameterEncoding?
    public var session: NetworkingSessionProtocol
    public var serializer: Serializer
    public var timeoutInterval: TimeInterval?
    public var adapter: NetworkingAdapter?
    public var retrier: NetworkingRetrier?
    public var interceptor: NetworkingInterceptor?
    public var observers: [NetworkingTransportObserver]
    public var byteChunkSize: Int
    public var mockChunks: [Result<Data, Error>]

    public init(baseUrl: String,
                path: String = "",
                method: NetworkingRouteHttpMethod = .get,
                headers: NetworkingRouteHttpHeaders? = nil,
                parameterEncoding: NetworkingRouteParameterEncoding? = nil,
                session: NetworkingSessionProtocol = NetworkingSession.shared,
                serializer: Serializer,
                timeoutInterval: TimeInterval? = nil,
                adapter: NetworkingAdapter? = nil,
                retrier: NetworkingRetrier? = nil,
                interceptor: NetworkingInterceptor? = nil,
                observers: [NetworkingTransportObserver] = [],
                byteChunkSize: Int = networkingDefaultByteChunkSize,
                mockChunks: [Result<Data, Error>] = []) {
        self.baseUrl = baseUrl
        self.path = path
        self.method = method
        self.headers = headers
        self.parameterEncoding = parameterEncoding
        self.session = session
        self.serializer = serializer
        self.timeoutInterval = timeoutInterval
        self.adapter = adapter
        self.retrier = retrier
        self.interceptor = interceptor
        self.observers = observers
        self.byteChunkSize = byteChunkSize
        self.mockChunks = mockChunks
    }
}
