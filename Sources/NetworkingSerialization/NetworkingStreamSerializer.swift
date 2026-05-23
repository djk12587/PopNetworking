//
//  NetworkingStreamSerializer.swift
//  PopNetworking
//

import Foundation

/// A `NetworkingStreamSerializer` parses an incoming byte stream into a stream of
/// typed ``Chunk`` values. It is the streaming analog of ``NetworkingResponseSerializer``.
///
/// The serializer receives the live byte stream and the initial `URLResponse` and either:
///
/// 1. Throws synchronously (before returning the stream) to signal the response is unacceptable
///    — e.g. on a non-2xx status code. The session catches the throw and consults the retrier,
///    so this is how status-based retry is wired up for streaming routes.
///
/// 2. Returns an `AsyncThrowingStream<Chunk, Error>` for the consumer to iterate. Mid-stream
///    parsing errors propagate via the returned stream's throwing termination; they do not
///    trigger the retrier (the stream has already been handed to the consumer at that point).
///
/// Cancellation is forwarded: when the returned stream's continuation terminates (consumer
/// stops iterating, downstream error, downstream cancellation), the serializer is expected to
/// stop iterating `byteStream` so the upstream resource can be released.
///
/// Prebuilt streaming serializers live in ``NetworkingSerializers/Stream``.
@available(iOS 15, macOS 12, tvOS 15, watchOS 8, visionOS 1, *)
public protocol NetworkingStreamSerializer: Sendable {

    /// The typed value produced for each parsed chunk in the byte stream (e.g. an SSE event,
    /// one decoded JSON line, or a raw `Data` chunk for passthrough).
    associatedtype Chunk: Sendable

    /// Transforms an upstream byte-chunk stream + URLResponse into a typed chunk stream.
    ///
    /// Throw to reject the response before any chunk is returned to the consumer (status-based
    /// retry path). Otherwise, return the live stream.
    ///
    /// - Parameters:
    ///   - byteStream: The live byte-chunk stream from the network.
    ///   - urlResponse: The initial `URLResponse` (status code, headers).
    /// - Returns: A typed chunk stream the consumer iterates.
    func stream(
        byteStream: AsyncThrowingStream<Data, Error>,
        urlResponse: URLResponse
    ) async throws -> AsyncThrowingStream<Chunk, Error>
}
