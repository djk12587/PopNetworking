//
//  File.swift
//
//
//  Created by Dan_Koza on 11/11/21.
//

import Foundation

/// `URLSessionProtocol` is responsible for executing a `URLRequest`. Two surfaces:
/// * ``data(for:)`` returns the full response body as `(Data, URLResponse)` — used by ``NetworkingResponseRoute``.
/// * ``bytes(for:byteChunkSize:)`` returns the response body as an `AsyncThrowingStream<Data, Error>` plus a cancel closure — used by ``NetworkingStreamRoute``.
///
/// - Note: PopNetworking extends `URLSession` to conform to ``URLSessionProtocol``.
public protocol URLSessionProtocol: Sendable {

    var session: URLSession { get }
    func data(for request: URLRequest) async throws -> (Data, URLResponse)

    /// Executes a `URLRequest` and returns the response body as a stream of `Data` chunks
    /// along with a closure that cancels the underlying transport.
    ///
    /// Bytes are pulled from the underlying byte source (e.g. `URLSession.AsyncBytes`) and
    /// batched into `Data` chunks of `byteChunkSize` bytes. The buffer flushes when full or
    /// when the upstream finishes.
    ///
    /// **About the cancel closure**: cancellation of multi-layered `AsyncThrowingStream`s
    /// is unreliable through Swift Concurrency's iterator-deinit pathway. The cancel closure
    /// is the framework's explicit cleanup handle for the underlying byte source (e.g. it
    /// calls `URLSessionDataTask.cancel()` for the real `URLSession` implementation). The
    /// session invokes it from the consumer-facing wrapper's `onTermination` so that breaking
    /// iteration tears down the network resources promptly. Mocks that don't have a real
    /// task return a no-op closure.
    ///
    /// - Parameters:
    ///   - request: The `URLRequest` to execute.
    ///   - byteChunkSize: Maximum bytes accumulated per `Data` chunk.
    /// - Returns: A tuple of `(byteStream, urlResponse, cancelStream)` where `cancelStream`
    ///   tears down the underlying byte source.
    @available(iOS 15, macOS 12, tvOS 15, watchOS 8, visionOS 1, *)
    func bytes(
        for request: URLRequest,
        byteChunkSize: Int
    ) async throws -> (AsyncThrowingStream<Data, Error>, URLResponse, @Sendable () -> Void)
}

extension URLSession: URLSessionProtocol {

    public var session: URLSession { self }

    @available(iOS 15, macOS 12, tvOS 15, watchOS 8, visionOS 1, *)
    public func bytes(
        for request: URLRequest,
        byteChunkSize: Int
    ) async throws -> (AsyncThrowingStream<Data, Error>, URLResponse, @Sendable () -> Void) {
        let (asyncBytes, response) = try await self.bytes(for: request)
        let dataTask = asyncBytes.task
        let stream = networkingDataChunkStream(from: asyncBytes, chunkSize: byteChunkSize)
        return (stream, response, { dataTask.cancel() })
    }
}
