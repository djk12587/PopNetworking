//
//  NetworkingHooks.swift
//  PopNetworking
//

import Foundation

/// ``NetworkingHooks`` declares the hooks attached to a networking call: the adapter that
/// can mutate the request before it is sent, the retrier that decides whether to re-attempt
/// after a failure, the interceptor that combines both, and the observers that watch the call's
/// lifecycle.
///
/// Shared by ``NetworkingResponseRoute`` and ``NetworkingStreamRoute``. Both response and streaming
/// routes use the same hook protocols around the underlying transport call; the session decides
/// when each one fires.
public protocol NetworkingHooks: Sendable {

    /// ``NetworkingAdapter`` tied to the call.
    ///
    /// Session-level and route-level adapters (including any
    /// ``NetworkingInterceptor``'s adapter function) are merged and sorted by
    /// ``NetworkingPriority``. Higher-priority adapters run first.
    var adapter: NetworkingAdapter? { get }

    /// ``NetworkingRetrier`` tied to the call.
    ///
    /// Session-level and route-level retriers (including any
    /// ``NetworkingInterceptor``'s retrier function) are merged and sorted by
    /// ``NetworkingPriority``. Higher-priority retriers run first.
    var retrier: NetworkingRetrier? { get }

    /// ``NetworkingInterceptor`` tied to the call.
    ///
    /// An interceptor acts as both an adapter and a retrier. Its adapter function
    /// is merged into the adapter chain; its retrier function into the retrier chain.
    /// Both are sorted by ``NetworkingPriority`` alongside any standalone adapters
    /// and retriers.
    var interceptor: NetworkingInterceptor? { get }

    /// ``NetworkingTransportObserver``s tied to the call.
    ///
    /// Session-level and route-level observers fire concurrently for each lifecycle event with
    /// no ordering guarantee between them.
    var observers: [NetworkingTransportObserver] { get }
}

public extension NetworkingHooks {
    var adapter: NetworkingAdapter? { nil }
    var retrier: NetworkingRetrier? { nil }
    var interceptor: NetworkingInterceptor? { nil }
    var observers: [NetworkingTransportObserver] { [] }
}
