//
//  Networking+Session.swift
//  PopNetworking
//
//  Created by Daniel Koza on 1/8/21.
//  Copyright © 2021 Daniel Koza. All rights reserved.
//

import Foundation

/// `NetworkingSessionProtocol` is responsible for executing an instance of ``NetworkingResponseRoute``
/// (returning its serialized object) or a ``NetworkingStreamRoute`` (returning its typed chunk
/// stream).
public protocol NetworkingSessionProtocol: Sendable {

    var urlSession: URLSession { get }
    func execute<ResponseRoute: NetworkingResponseRoute>(route: ResponseRoute) async throws -> ResponseRoute.Serializer.SerializedObject

    /// Executes a streaming route and returns its typed chunk stream. Conformers compiled for
    /// iOS 15+ must implement this; conformers compiled for iOS 13 do not see this requirement.
    @available(iOS 15, macOS 12, tvOS 15, watchOS 8, visionOS 1, *)
    func executeStream<ResponseRoute: NetworkingStreamRoute>(route: ResponseRoute) async throws
        -> AsyncThrowingStream<ResponseRoute.Serializer.Chunk, Error>
}

public extension NetworkingSession {
    /// A singleton ``NetworkingSession`` object.
    ///
    /// The ``NetworkingSession`` class provides a shared singleton session object that utilizes `URLSession` with a `URLSessionConfiguration.default` configuration.
    static let shared = NetworkingSession()
}

/// ``NetworkingSession`` is a wrapper class for `URLSession`. Conforms to ``NetworkingSessionProtocol``.
///
/// Route execution lifecycles live in the corresponding extension files:
/// * Response (`NetworkingResponseRoute`): see ``NetworkingSession/execute(route:)`` in `NetworkingSession+ResponseRoute.swift`
/// * Stream (`NetworkingStreamRoute`): see ``NetworkingSession/executeStream(route:)`` in `NetworkingSession+StreamRoute.swift`
public final class NetworkingSession: NetworkingSessionProtocol {

    public var urlSession: URLSession { self._urlSession.session }

    internal let _urlSession: URLSessionProtocol
    internal let adapter: NetworkingAdapter?
    internal let retrier: NetworkingRetrier?
    internal let observers: [NetworkingTransportObserver]

    /// Creates an instance of a ``NetworkingSession``.
    /// - Parameters:
    ///   - urlSession: The ``URLSessionProtocol`` that executes the HTTP requests. `URLSession` conforms to ``URLSessionProtocol``.
    ///   - adapter: The ``NetworkingAdapter`` that runs for every route executed on this session.
    ///   - retrier: The ``NetworkingRetrier`` that runs for every route executed on this session.
    ///   - observers: The ``NetworkingTransportObserver``s that run for every route. All observers fire concurrently for each lifecycle event.
    public init(urlSession: URLSessionProtocol = URLSession(configuration: .default),
                adapter: NetworkingAdapter? = nil,
                retrier: NetworkingRetrier? = nil,
                observers: [NetworkingTransportObserver] = []) {
        self.adapter = adapter
        self.retrier = retrier
        self.observers = observers
        self._urlSession = urlSession
    }

    /// Creates an instance of a ``NetworkingSession`` with a shared ``NetworkingInterceptor``.
    /// - Parameters:
    ///   - urlSession: The ``URLSessionProtocol`` that executes the HTTP requests. `URLSession` conforms to ``URLSessionProtocol``.
    ///   - interceptor: The ``NetworkingInterceptor`` that runs for every route executed on this session.
    ///   - observers: The ``NetworkingTransportObserver``s that run for every route. All observers fire concurrently for each lifecycle event.
    public init(urlSession: URLSessionProtocol = URLSession(configuration: .default),
                interceptor: NetworkingInterceptor?,
                observers: [NetworkingTransportObserver] = []) {
        self.adapter = interceptor
        self.retrier = interceptor
        self.observers = observers
        self._urlSession = urlSession
    }
}
