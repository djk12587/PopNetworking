//
//  NetworkingTransportObserver.swift
//  PopNetworking
//

import Foundation

/// Allows you to observe a `URLRequest`'s lifecycle without modifying its behavior.
///
/// ``NetworkingTransportObserver`` is a side-effect-only hook. Conformers cannot throw, mutate the request, or influence retry — they
/// just watch. Use it for logging, analytics, breadcrumbs, etc. For mutation use ``NetworkingAdapter``; for retry decisions
/// use ``NetworkingRetrier``.
///
/// Observers fire **per attempt**: every retry produces its own ``willSend(urlRequest:)`` followed by either
/// ``didReceive(data:urlResponse:)`` or ``didFail(urlRequest:dueTo:)``.
///
/// When both a session-level and a route-level observer are registered, they fire concurrently with no ordering guarantee between them.
///
/// ## Execution
/// Observer callbacks run **inline** on the request path — `willSend` runs before `URLSession.data(for:)` is called,
/// and `didReceive` / `didFail` run before the next attempt begins. A slow observer slows every request.
///
/// For expensive work (file I/O, third-party analytics SDKs) where you don't need the temporal guarantees, spawn a
/// `Task` inside the callback and return immediately:
///
/// ```swift
/// func willSend(urlRequest: URLRequest) async {
///     Task.detached { await self.expensiveLog(urlRequest) }
/// }
/// ```
///
/// This makes the trade-off (deferred work, no ordering with the request lifecycle) explicit at the call site.
public protocol NetworkingTransportObserver: Sendable {

    /// Fires after all adapters complete and just before the `URLRequest` is sent over the wire.
    /// - Parameter urlRequest: The adapted `URLRequest` about to be executed by `URLSession`.
    func willSend(urlRequest: URLRequest) async

    /// Fires when `URLSession.data(for:)` returns successfully, before validator/serializer processing.
    /// - Parameters:
    ///   - data: The raw response body.
    ///   - urlResponse: The raw `URLResponse`.
    func didReceive(data: Data, urlResponse: URLResponse) async

    /// Fires when `URLSession.data(for:)` throws a transport-level error. Validator and serializer failures do NOT trigger this — in those cases ``didReceive(data:urlResponse:)`` already fired with the raw bytes.
    /// - Parameters:
    ///   - urlRequest: The `URLRequest` that was sent.
    ///   - error: The transport error.
    func didFail(urlRequest: URLRequest, dueTo error: Error) async
}

internal extension Array where Element == NetworkingTransportObserver {

    /// Calls `notify` on every observer in the array concurrently, awaiting all to complete.
    /// Use this to fire a single lifecycle event across all registered observers without
    /// imposing a serial wait between them.
    func notifyConcurrently(_ notify: @escaping @Sendable (NetworkingTransportObserver) async -> Void) async {
        await withTaskGroup(of: Void.self) { group in
            for observer in self {
                group.addTask { await notify(observer) }
            }
        }
    }
}
