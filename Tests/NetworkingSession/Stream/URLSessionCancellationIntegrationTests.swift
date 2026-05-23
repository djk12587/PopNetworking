//
//  URLSessionCancellationIntegrationTests.swift
//  PopNetworking
//
//  Integration test for the cancellation chain through a real `URLSession` +
//  `URLSession.AsyncBytes`. The bridge's isolated unit tests can't exercise this — a generic
//  `AsyncThrowingStream` source doesn't propagate cancellation through iterator-deinit, so
//  that test would only confirm the bridge's bookkeeping. The PRODUCTION chain works because
//  Apple's `URLSession.AsyncBytes` cancels the underlying `URLSessionDataTask` when the
//  iterator's `next()` observes cancellation. This test verifies that end-to-end through a
//  stubbed `URLProtocol`.
//

import XCTest
@testable import PopNetworking

@available(iOS 15, macOS 12, tvOS 15, watchOS 8, visionOS 1, *)
final class URLSessionCancellationIntegrationTests: XCTestCase {

    /// Thread-safe observation point for the stubbed `URLProtocol`. Uses `NSLock` (not an
    /// actor) so `stopLoading()` can record synchronously from URLSession's internal queue
    /// — no async hop, no race between the protocol firing and the test polling.
    final class ProbeState: @unchecked Sendable {
        private let lock = NSLock()
        private var _startCount = 0
        private var _stopCount = 0
        private var _bytesEmitted = 0

        var startCount: Int { lock.lock(); defer { lock.unlock() }; return _startCount }
        var stopCount: Int { lock.lock(); defer { lock.unlock() }; return _stopCount }
        var bytesEmitted: Int { lock.lock(); defer { lock.unlock() }; return _bytesEmitted }

        func recordStart() { lock.lock(); _startCount += 1; lock.unlock() }
        func recordStop() { lock.lock(); _stopCount += 1; lock.unlock() }
        func recordByte() { lock.lock(); _bytesEmitted += 1; lock.unlock() }
    }

    /// Test-only `URLProtocol` that streams bytes indefinitely (until cancelled). When the
    /// URL loading system cancels the task — which is what we expect to happen when the
    /// consumer of `route.stream` breaks early — `stopLoading()` fires and we record it.
    final class StubProtocol: URLProtocol, @unchecked Sendable {
        nonisolated(unsafe) static var probe: ProbeState?

        // Per-instance cancellation signal for the byte-feeding thread.
        private let cancelLock = NSLock()
        private var _isCancelled = false
        private var isCancelled: Bool {
            cancelLock.lock(); defer { cancelLock.unlock() }
            return _isCancelled
        }
        private func markCancelled() {
            cancelLock.lock(); _isCancelled = true; cancelLock.unlock()
        }

        override class func canInit(with request: URLRequest) -> Bool {
            request.url?.host == "cancellation-probe.local"
        }

        override class func canonicalRequest(for request: URLRequest) -> URLRequest {
            request
        }

        override func startLoading() {
            Self.probe?.recordStart()
            guard let url = request.url else { return }
            let response = HTTPURLResponse(url: url,
                                           statusCode: 200,
                                           httpVersion: "HTTP/1.1",
                                           headerFields: nil)!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)

            Thread.detachNewThread { [weak self] in
                guard let self else { return }
                var i: UInt8 = 0
                while !self.isCancelled {
                    self.client?.urlProtocol(self, didLoad: Data([i]))
                    Self.probe?.recordByte()
                    i = i &+ 1
                    Thread.sleep(forTimeInterval: 0.001)
                }
            }
        }

        override func stopLoading() {
            self.markCancelled()
            Self.probe?.recordStop()
        }
    }

    override func tearDown() async throws {
        StubProtocol.probe = nil
        try await super.tearDown()
    }

    // MARK: - Sanity: URLProtocol.stopLoading is actually wired up

    /// Calibration: confirms calling `URLSessionDataTask.cancel()` on the AsyncBytes' own
    /// task reference fires the URLProtocol's `stopLoading`. If this passes, then the new
    /// `dataTask.cancel()` mechanism inside `URLSession.bytes(for:byteChunkSize:)`
    /// is the right tool — and any remaining failure of the integration test is because
    /// the bridge's `onTermination` isn't firing reliably, not because of any AsyncBytes
    /// quirk.
    func test_calibration_directDataTaskCancel_firesStopLoading() async throws {
        let probe = ProbeState()
        StubProtocol.probe = probe

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubProtocol.self]
        let urlSession = URLSession(configuration: config)
        defer { urlSession.invalidateAndCancel() }

        let request = URLRequest(url: URL(string: "http://cancellation-probe.local/calibrate")!)
        let (asyncBytes, _) = try await urlSession.bytes(for: request)

        try await waitFor(timeout: 2.0) { probe.startCount > 0 }
        XCTAssertEqual(probe.startCount, 1)

        asyncBytes.task.cancel()

        try await waitFor(timeout: 2.0) { probe.stopCount > 0 }
        XCTAssertGreaterThanOrEqual(probe.stopCount, 1,
                                    "Calibration: URLSessionDataTask.cancel() on the AsyncBytes' task must trigger URLProtocol.stopLoading")
    }

    /// Calibration check: confirms the test infrastructure observes `stopLoading` when we
    /// explicitly cancel via `urlSession.invalidateAndCancel()`. If this fails, the rest of
    /// the suite can't be trusted — the probe itself is broken.
    func test_calibration_explicitInvalidateCancelsURLProtocol() async throws {
        let probe = ProbeState()
        StubProtocol.probe = probe

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubProtocol.self]
        let urlSession = URLSession(configuration: config)

        // Fire and forget: a long-running bytes(for:) request.
        let task = Task {
            try? await urlSession.bytes(for: URLRequest(url: URL(string: "http://cancellation-probe.local/x")!))
        }

        // Wait until startLoading fires.
        try await waitFor(timeout: 2.0) { probe.startCount > 0 }
        XCTAssertEqual(probe.startCount, 1)

        urlSession.invalidateAndCancel()
        task.cancel()

        // stopLoading should fire promptly after invalidation.
        try await waitFor(timeout: 2.0) { probe.stopCount > 0 }
        XCTAssertGreaterThanOrEqual(probe.stopCount, 1,
                                    "Calibration: invalidateAndCancel must cause stopLoading. If this fails, the URLProtocol observation itself is broken.")
    }

    // MARK: - The real test

    /// When the consumer of `route.stream` breaks iteration, the cancellation chain
    /// (consumer → wrapped stream → bridge Task → AsyncBytes iterator → URLSessionDataTask)
    /// must reach the URL loading system, which fires `stopLoading` on the URLProtocol.
    func test_consumerBreakingIteration_cancelsUnderlyingURLSessionTask() async throws {
        let probe = ProbeState()
        StubProtocol.probe = probe

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubProtocol.self]
        let urlSession = URLSession(configuration: config)
        defer { urlSession.invalidateAndCancel() }

        let session = NetworkingSession(urlSession: urlSession)
        let route = StreamRoute(
            baseUrl: "http://cancellation-probe.local",
            path: "stream",
            session: session,
            serializer: NetworkingSerializers.Stream.Data(),
            // Small chunk size so the bridge yields a chunk after only ~8 bytes — the
            // consumer can break early without waiting for the 16 KB default.
            byteChunkSize: 8
        )

        // Iterate inside a do-block so `stream` goes out of scope when the block exits.
        // AsyncThrowingStream's onTermination is observed to fire only when both the
        // iterator AND the stream itself are released; keeping `stream` alive past the loop
        // can suppress termination.
        var consumedChunks = 0
        do {
            let stream = try await route.stream
            for try await _ in stream {
                consumedChunks += 1
                if consumedChunks >= 1 { break }
            }
        }
        XCTAssertEqual(consumedChunks, 1)

        // Wait for cancellation to propagate the full chain. On a healthy machine this is
        // milliseconds; the 2s bound is a CI-variance safety net.
        try await waitFor(timeout: 2.0) { probe.stopCount > 0 }

        XCTAssertEqual(probe.startCount, 1, "exactly one request should have been started")
        XCTAssertGreaterThanOrEqual(probe.stopCount, 1,
                                    "stopLoading must fire when the consumer breaks — this is the production cancellation chain reaching the URLSessionDataTask via AsyncBytes' iterator")
    }

    /// The idiomatic Swift Concurrency pattern: wrap streaming work in a Task and cancel
    /// the Task to stop. Cancellation propagates through `withTaskCancellationHandler`
    /// inside AsyncThrowingStream's `next()`, which fires the wrapped stream's `onTermination`
    /// synchronously — no reliance on iterator-deinit timing. This is the canonical way to
    /// stop a stream and works regardless of whether the stream variable is held elsewhere.
    func test_consumerTaskCancellation_cancelsUnderlyingURLSessionTask() async throws {
        let probe = ProbeState()
        StubProtocol.probe = probe

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubProtocol.self]
        let urlSession = URLSession(configuration: config)
        defer { urlSession.invalidateAndCancel() }

        let session = NetworkingSession(urlSession: urlSession)
        let route = StreamRoute(
            baseUrl: "http://cancellation-probe.local",
            path: "stream",
            session: session,
            serializer: NetworkingSerializers.Stream.Data(),
            byteChunkSize: 8
        )

        // Iteration runs in a child Task. The stream is stored in a local — this would
        // expose the iterator-deinit gotcha if we relied on it, but we don't here: we
        // cancel via the Task instead, which is the idiomatic Swift Concurrency way.
        let streamTask = Task {
            let stream = try await route.stream
            for try await _ in stream {
                // intentionally never break; rely on outer cancellation
            }
        }

        // Let the stream get going.
        try await waitFor(timeout: 2.0) { probe.startCount > 0 }
        XCTAssertEqual(probe.startCount, 1)

        // Cancel the task — should propagate all the way down.
        streamTask.cancel()
        _ = try? await streamTask.value

        try await waitFor(timeout: 2.0) { probe.stopCount > 0 }
        XCTAssertGreaterThanOrEqual(probe.stopCount, 1,
                                    "Task.cancel() must propagate through to URLSessionDataTask.cancel() — this is the canonical streaming-cancellation pattern")
    }

    // MARK: - Helpers

    /// Polls `condition` with a 5ms cadence up to `timeout`. Returns when the condition is
    /// true or the timeout elapses. Used in place of XCTestExpectation here because the
    /// probe uses lock-based observation rather than continuations.
    private func waitFor(timeout: TimeInterval, condition: () -> Bool) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return }
            try? await Task.sleep(nanoseconds: 5_000_000)
        }
    }
}
