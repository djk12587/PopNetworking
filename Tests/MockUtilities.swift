//
//  File.swift
//  
//
//  Created by Dan_Koza on 11/11/21.
//

import Foundation
@testable import PopNetworking

enum Mock {

    struct ResponseRoute<Serializer: NetworkingResponseSerializer>: NetworkingResponseRoute {

        var baseUrl: String
        var path: String
        var method: NetworkingRouteHttpMethod
        var parameterEncoding: NetworkingRouteParameterEncoding?
        var session: NetworkingSessionProtocol
        var serializer: Serializer
        var mockSerializedResult: Result<Serializer.SerializedObject, Error>?
        var timeoutInterval: TimeInterval?
        var repeater: Repeater?
        var adapter: NetworkingAdapter?
        var retrier: NetworkingRetrier?
        var interceptor: NetworkingInterceptor?
        var observers: [NetworkingTransportObserver]

        init(baseUrl: String = "https://mockUrl.com",
             path: String = "",
             method: NetworkingRouteHttpMethod = .get,
             parameterEncoding: NetworkingRouteParameterEncoding? = nil,
             session: NetworkingSessionProtocol = NetworkingSession(urlSession: Mock.UrlSession()),
             serializer: Serializer,
             timeoutInterval: TimeInterval? = nil,
             mockSerializedResult: Result<Serializer.SerializedObject, Error>? = nil,
             adapter: NetworkingAdapter? = nil,
             retrier: NetworkingRetrier? = nil,
             interceptor: NetworkingInterceptor? = nil,
             observers: [NetworkingTransportObserver] = [],
             repeater: Repeater? = nil) {
            self.baseUrl = baseUrl
            self.path = path
            self.method = method
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

    struct UrlSession: URLSessionProtocol {

        private actor SafeMutableData {
            private(set) var lastRequest: URLRequest?

            func set(lastRequest: URLRequest?) {
                self.lastRequest = lastRequest
            }
        }
        var session: URLSession { URLSession(configuration: .default) }
        private let mutableData = SafeMutableData()
        let mockResult: Result<Data, Error>
        let mockUrlResponse: URLResponse?
        let mockDelay: TimeInterval?
        /// When non-empty, ``bytes(for:byteChunkSize:)`` yields this sequence of chunks
        /// instead of a single chunk derived from ``mockResult``. Use to simulate chunk-
        /// spanning event boundaries or a mid-stream error.
        let mockBytesChunks: [Result<Data, Error>]
        var lastRequest: URLRequest? {
            get async { await self.mutableData.lastRequest }
        }

        init(mockResult: Result<Data, Error> = .success(Data()),
             mockUrlResponse: URLResponse? = nil,
             mockDelay: TimeInterval? = nil,
             mockBytesChunks: [Result<Data, Error>] = []) {
            self.mockResult = mockResult
            self.mockUrlResponse = mockUrlResponse
            self.mockDelay = mockDelay
            self.mockBytesChunks = mockBytesChunks
        }

        func data(for request: URLRequest) async throws -> (Data, URLResponse) {
            try? await Task.sleep(nanoseconds: UInt64(mockDelay ?? 0) * 1_000_000_000)
            await self.mutableData.set(lastRequest: request)
            return (try mockResult.get(), self.mockUrlResponse ?? URLResponse())
        }

        func data(for request: URLRequest, delegate: URLSessionTaskDelegate?) async throws -> (Data, URLResponse) {
            try await self.data(for: request)
        }

        @available(iOS 15, macOS 12, tvOS 15, watchOS 8, visionOS 1, *)
        func bytes(
            for request: URLRequest,
            byteChunkSize: Int
        ) async throws -> (AsyncThrowingStream<Data, Error>, URLResponse, @Sendable () -> Void) {
            try? await Task.sleep(nanoseconds: UInt64(mockDelay ?? 0) * 1_000_000_000)
            await self.mutableData.set(lastRequest: request)

            // Connection failure: throws before any stream is returned.
            if case .failure(let error) = self.mockResult {
                throw error
            }

            let chunks: [Result<Data, Error>]
            if !self.mockBytesChunks.isEmpty {
                chunks = self.mockBytesChunks
            } else if case .success(let data) = self.mockResult, !data.isEmpty {
                chunks = [.success(data)]
            } else {
                chunks = []
            }

            let stream = AsyncThrowingStream<Data, Error>(bufferingPolicy: .unbounded) { continuation in
                let task = Task {
                    for chunk in chunks {
                        if Task.isCancelled { break }
                        switch chunk {
                        case .success(let data):
                            continuation.yield(data)
                        case .failure(let error):
                            continuation.finish(throwing: error)
                            return
                        }
                    }
                    continuation.finish()
                }
                continuation.onTermination = { _ in task.cancel() }
            }
            // No real URLSessionDataTask backs this mock; cancel closure is a no-op.
            return (stream, self.mockUrlResponse ?? URLResponse(), { })
        }
    }

    /// A `URLSessionProtocol` that returns a different `mockResults[i]` per call. Use when a single test
    /// needs to exercise multiple attempts (e.g. transport failure followed by success across a retry).
    struct UrlSessions: URLSessionProtocol {

        private actor SafeMutableData {
            var index = 0
            private(set) var lastRequest: URLRequest?

            func consumeNextIndex() -> Int {
                let current = self.index
                self.index += 1
                return current
            }

            func set(lastRequest: URLRequest?) {
                self.lastRequest = lastRequest
            }
        }

        var session: URLSession { URLSession(configuration: .default) }
        private let mutableData = SafeMutableData()
        let mockResults: [Result<Data, Error>]
        let mockUrlResponses: [URLResponse?]
        /// Per-attempt chunk overrides for ``bytes(for:byteChunkSize:)``. Each element
        /// corresponds to one call attempt (mirroring `mockResults`). When an entry is
        /// non-empty, it overrides the single-chunk derivation from `mockResults[index]`.
        let mockBytesChunksByAttempt: [[Result<Data, Error>]]
        var lastRequest: URLRequest? {
            get async { await self.mutableData.lastRequest }
        }

        init(mockResults: [Result<Data, Error>],
             mockUrlResponses: [URLResponse?] = [],
             mockBytesChunksByAttempt: [[Result<Data, Error>]] = []) {
            self.mockResults = mockResults
            self.mockUrlResponses = mockUrlResponses
            self.mockBytesChunksByAttempt = mockBytesChunksByAttempt
        }

        func data(for request: URLRequest) async throws -> (Data, URLResponse) {
            await self.mutableData.set(lastRequest: request)
            let index = await self.mutableData.consumeNextIndex()
            guard index < self.mockResults.count else {
                fatalError("out of bounds: index >= mockResults.count")
            }
            let response = (index < self.mockUrlResponses.count ? self.mockUrlResponses[index] : nil) ?? URLResponse()
            return (try self.mockResults[index].get(), response)
        }

        func data(for request: URLRequest, delegate: URLSessionTaskDelegate?) async throws -> (Data, URLResponse) {
            try await self.data(for: request)
        }

        @available(iOS 15, macOS 12, tvOS 15, watchOS 8, visionOS 1, *)
        func bytes(
            for request: URLRequest,
            byteChunkSize: Int
        ) async throws -> (AsyncThrowingStream<Data, Error>, URLResponse, @Sendable () -> Void) {
            await self.mutableData.set(lastRequest: request)
            let index = await self.mutableData.consumeNextIndex()
            guard index < self.mockResults.count else {
                fatalError("out of bounds: index >= mockResults.count")
            }
            let response = (index < self.mockUrlResponses.count ? self.mockUrlResponses[index] : nil) ?? URLResponse()

            if case .failure(let error) = self.mockResults[index] {
                throw error
            }

            let chunks: [Result<Data, Error>]
            if index < self.mockBytesChunksByAttempt.count, !self.mockBytesChunksByAttempt[index].isEmpty {
                chunks = self.mockBytesChunksByAttempt[index]
            } else if case .success(let data) = self.mockResults[index], !data.isEmpty {
                chunks = [.success(data)]
            } else {
                chunks = []
            }

            let stream = AsyncThrowingStream<Data, Error>(bufferingPolicy: .unbounded) { continuation in
                let task = Task {
                    for chunk in chunks {
                        if Task.isCancelled { break }
                        switch chunk {
                        case .success(let data):
                            continuation.yield(data)
                        case .failure(let error):
                            continuation.finish(throwing: error)
                            return
                        }
                    }
                    continuation.finish()
                }
                continuation.onTermination = { _ in task.cancel() }
            }
            // No real URLSessionDataTask backs this mock; cancel closure is a no-op.
            return (stream, response, { })
        }
    }

    @available(iOS 15, macOS 12, tvOS 15, watchOS 8, visionOS 1, *)
    struct StreamRoute<Serializer: NetworkingStreamSerializer>: NetworkingStreamRoute {

        var baseUrl: String
        var path: String
        var method: NetworkingRouteHttpMethod
        var parameterEncoding: NetworkingRouteParameterEncoding?
        var session: NetworkingSessionProtocol
        var serializer: Serializer
        var timeoutInterval: TimeInterval?
        var adapter: NetworkingAdapter?
        var retrier: NetworkingRetrier?
        var interceptor: NetworkingInterceptor?
        var observers: [NetworkingTransportObserver]
        var byteChunkSize: Int
        var mockChunks: [Result<Data, Error>]

        init(baseUrl: String = "https://mockUrl.com",
             path: String = "",
             method: NetworkingRouteHttpMethod = .get,
             parameterEncoding: NetworkingRouteParameterEncoding? = nil,
             session: NetworkingSessionProtocol = NetworkingSession(urlSession: Mock.UrlSession()),
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

    enum Response {

        struct Serializer<SuccessType: Sendable>: NetworkingResponseSerializer {

            let serializedResult: Result<SuccessType, Error>

            init(_ serializedResult: Result<SuccessType, Error> = .success(())) {
                self.serializedResult = serializedResult
            }

            func serialize(responseResult: Result<(Data, URLResponse), Error>) async -> Result<SuccessType, Error> {
                switch responseResult {
                case .success:
                    return self.serializedResult
                case .failure(let failure):
                    return .failure(failure)
                }
            }
        }

        struct Serializers<SuccessType: Sendable>: NetworkingResponseSerializer {

            private actor Index {
                var value = 0

                func updateIndex() {
                    self.value += 1
                }
            }

            let serializedResults: [Result<SuccessType, Error>]
            private let index = Index()

            init(_ serializedResults: [Result<SuccessType, Error>] = [.success(())]) {
                self.serializedResults = serializedResults
            }

            func serialize(responseResult: Result<(Data, URLResponse), Error>) async -> Result<SuccessType, Error> {
                let index = await self.index.value
                await self.index.updateIndex()
                guard index < self.serializedResults.count else { fatalError("out of bounds: index > serializedResults.count") }
                switch responseResult {
                case .success:
                    return self.serializedResults[index]
                case .failure(let failure):
                    return .failure(failure)
                }
            }
        }
    }

    @available(iOS 15, macOS 12, tvOS 15, watchOS 8, visionOS 1, *)
    enum Stream {

        /// Configurable streaming serializer. Inject `behavior` to control what `stream(...)`
        /// returns or throws.
        struct Serializer<Chunk: Sendable>: NetworkingStreamSerializer {

            typealias Behavior = @Sendable (AsyncThrowingStream<Data, Error>, URLResponse) async throws -> AsyncThrowingStream<Chunk, Error>

            let behavior: Behavior

            init(behavior: @escaping Behavior) {
                self.behavior = behavior
            }

            func stream(byteStream: AsyncThrowingStream<Data, Error>,
                        urlResponse: URLResponse) async throws -> AsyncThrowingStream<Chunk, Error> {
                try await self.behavior(byteStream, urlResponse)
            }

            /// Throws synchronously from `stream(...)`. Triggers the connect-time retry path.
            static func throwImmediately(_ error: Error) -> Self {
                Self { _, _ in throw error }
            }

            /// Yields the supplied chunks then finishes cleanly. Does not consume the byte stream.
            static func yieldChunks(_ chunks: [Chunk]) -> Self {
                Self { _, _ in
                    AsyncThrowingStream<Chunk, Error> { continuation in
                        Task {
                            for chunk in chunks { continuation.yield(chunk) }
                            continuation.finish()
                        }
                    }
                }
            }

            /// Yields the supplied chunks then throws `finalError`. Used to simulate a mid-stream
            /// error after some chunks have already reached the consumer.
            static func yieldThenError(_ chunks: [Chunk], error: Error) -> Self {
                Self { _, _ in
                    AsyncThrowingStream<Chunk, Error> { continuation in
                        Task {
                            for chunk in chunks { continuation.yield(chunk) }
                            continuation.finish(throwing: error)
                        }
                    }
                }
            }
        }

        /// Convenience: a `Data`-passthrough streaming serializer that forwards each upstream
        /// `Data` chunk verbatim. Useful when tests want chunk-for-chunk fidelity from the
        /// route's `mockChunks` to the consumer.
        static func dataPassthroughSerializer() -> Serializer<Data> {
            Serializer<Data> { byteStream, _ in
                AsyncThrowingStream<Data, Error> { continuation in
                    let task = Task {
                        do {
                            for try await chunk in byteStream {
                                continuation.yield(chunk)
                            }
                            continuation.finish()
                        } catch {
                            continuation.finish(throwing: error)
                        }
                    }
                    continuation.onTermination = { _ in task.cancel() }
                }
            }
        }
    }

    struct Interceptor: NetworkingInterceptor {

        enum AdapterResult {
            case doNotAdapt
            case adapt(adaptedUrlRequest: URLRequest)
            case failure(error: Error)
        }

        private actor SafeMutableData {

            var adapterDidRun = false
            var adapterResults: [AdapterResult]
            var retrierDidRun = false
            var retrierResults: [NetworkingRetrierResult]
            var retrierPayload: (urlRequest: URLRequest?, error: Error, urlResponse: URLResponse?, retryCount: Int)?
            var retryCounter = 0
            var adapterRunDate: Date?
            var retrierRunDate: Date?

            init(adapterDidRun: Bool = false,
                 adapterResult: AdapterResult?,
                 adapterResults: [AdapterResult],
                 retrierDidRun: Bool = false,
                 retrierResult: NetworkingRetrierResult?,
                 retrierResults: [NetworkingRetrierResult],
                 retrierPayload: (urlRequest: URLRequest?, error: Error, urlResponse: HTTPURLResponse?, retryCount: Int)? = nil,
                 retryCounter: Int = 0,
                 ranDate: Date? = nil) {
                self.adapterDidRun = adapterDidRun
                self.adapterResults = [adapterResult].compactMap({ $0 }) + adapterResults
                self.retrierDidRun = retrierDidRun
                self.retrierResults = [retrierResult].compactMap({ $0 }) + retrierResults
                self.retrierPayload = retrierPayload
                self.retryCounter = retryCounter
            }

            func set(adapterDidRun: Bool) {
                self.adapterDidRun = adapterDidRun
            }

            func set(retrierDidRun: Bool) {
                self.retrierDidRun = retrierDidRun
            }

            func set(retrierPayload: (urlRequest: URLRequest?, error: Error, urlResponse: URLResponse?, retryCount: Int)?) {
                self.retrierPayload = retrierPayload
            }

            func set(retryCounter: Int) {
                self.retryCounter = retryCounter
            }

            func set(adapterRunDate: Date) {
                self.adapterRunDate = adapterRunDate
            }

            func set(retrierRunDate: Date) {
                self.retrierRunDate = retrierRunDate
            }

            var adapterResult: AdapterResult? {
                guard !self.adapterResults.isEmpty else { return nil }
                return self.adapterResults.removeFirst()
            }

            var retrierResult: NetworkingRetrierResult? {
                guard !self.retrierResults.isEmpty else { return nil }
                return self.retrierResults.removeFirst()
            }
        }

        private let mutableData: SafeMutableData
        var adapterDidRun: Bool { get async { await self.mutableData.adapterDidRun } }
        var retrierDidRun: Bool { get async { await self.mutableData.retrierDidRun } }
        var retryCounter: Int { get async { await self.mutableData.retryCounter } }
        var retrierPayload: (urlRequest: URLRequest?, error: Error, urlResponse: URLResponse?, retryCount: Int)? {
            get async { await self.mutableData.retrierPayload }
        }
        var adapterRunDate: Date? { get async { await self.mutableData.adapterRunDate } }
        var retrierRunDate: Date? { get async { await self.mutableData.retrierRunDate } }
        let priority: NetworkingPriority

        init(adapterResult: AdapterResult? = nil,
             retrierResult: NetworkingRetrierResult? = nil,
             adapterResults: [AdapterResult] = [],
             retrierResults: [NetworkingRetrierResult] = [],
             priority: NetworkingPriority = .standard) {
            self.mutableData = SafeMutableData(adapterResult: adapterResult,
                                               adapterResults: adapterResults,
                                               retrierResult: retrierResult,
                                               retrierResults: retrierResults)
            self.priority = priority
        }

        func adapt(urlRequest: URLRequest) async throws -> URLRequest {
            await self.mutableData.set(adapterRunDate: Date())
            await self.mutableData.set(adapterDidRun: true)

            guard let adapterResult = await self.mutableData.adapterResult else { return urlRequest }

            switch adapterResult {
            case .doNotAdapt:
                return urlRequest
            case .adapt(let adaptedUrlRequest):
                return adaptedUrlRequest
            case .failure(let error):
                throw error
            }
        }

        func retry(urlRequest: URLRequest?, dueTo error: any Error, urlResponse: URLResponse?, retryCount: Int) async -> NetworkingRetrierResult {
            await self.mutableData.set(retrierRunDate: Date())
            await self.mutableData.set(retrierPayload: (urlRequest, error, urlResponse, retryCount))
            await self.mutableData.set(retrierDidRun: true)
            await self.mutableData.set(retryCounter: await self.mutableData.retryCounter + 1)

            guard let retrierResult = await self.mutableData.retrierResult else { return .doNotRetry }

            return retrierResult
        }

    }

    struct Observer: NetworkingTransportObserver {

        private actor SafeMutableData {
            var willSendDidRun = false
            var didReceiveDidRun = false
            var didFailDidRun = false
            var willBeginStreamDidRun = false
            var didFinishStreamDidRun = false
            var capturedWillSendUrlRequest: URLRequest?
            var capturedDidReceiveData: Data?
            var capturedDidReceiveUrlResponse: URLResponse?
            var capturedDidFailUrlRequest: URLRequest?
            var capturedDidFailError: Error?
            var capturedWillBeginStreamUrlRequest: URLRequest?
            var capturedWillBeginStreamUrlResponse: URLResponse?
            var capturedDidFinishStreamUrlRequest: URLRequest?
            var capturedDidFinishStreamUrlResponse: URLResponse?
            var capturedDidFinishStreamError: Error?
            var willSendCallCount = 0
            var didReceiveCallCount = 0
            var didFailCallCount = 0
            var willBeginStreamCallCount = 0
            var didFinishStreamCallCount = 0
            /// Order of lifecycle events as they fire. Useful for asserting observer-event
            /// ordering on streaming routes (e.g. willSend → willBeginStream → didFinishStream).
            var eventLog: [String] = []

            func recordWillSend(urlRequest: URLRequest) {
                self.willSendDidRun = true
                self.capturedWillSendUrlRequest = urlRequest
                self.willSendCallCount += 1
                self.eventLog.append("willSend")
            }

            func recordDidReceive(data: Data, urlResponse: URLResponse) {
                self.didReceiveDidRun = true
                self.capturedDidReceiveData = data
                self.capturedDidReceiveUrlResponse = urlResponse
                self.didReceiveCallCount += 1
                self.eventLog.append("didReceive")
            }

            func recordDidFail(urlRequest: URLRequest, error: Error) {
                self.didFailDidRun = true
                self.capturedDidFailUrlRequest = urlRequest
                self.capturedDidFailError = error
                self.didFailCallCount += 1
                self.eventLog.append("didFail")
            }

            func recordWillBeginStream(urlRequest: URLRequest, urlResponse: URLResponse) {
                self.willBeginStreamDidRun = true
                self.capturedWillBeginStreamUrlRequest = urlRequest
                self.capturedWillBeginStreamUrlResponse = urlResponse
                self.willBeginStreamCallCount += 1
                self.eventLog.append("willBeginStream")
            }

            func recordDidFinishStream(urlRequest: URLRequest, urlResponse: URLResponse, error: Error?) {
                self.didFinishStreamDidRun = true
                self.capturedDidFinishStreamUrlRequest = urlRequest
                self.capturedDidFinishStreamUrlResponse = urlResponse
                self.capturedDidFinishStreamError = error
                self.didFinishStreamCallCount += 1
                self.eventLog.append("didFinishStream")
            }
        }

        private let mutableData = SafeMutableData()

        var willSendDidRun: Bool { get async { await self.mutableData.willSendDidRun } }
        var didReceiveDidRun: Bool { get async { await self.mutableData.didReceiveDidRun } }
        var didFailDidRun: Bool { get async { await self.mutableData.didFailDidRun } }
        var willBeginStreamDidRun: Bool { get async { await self.mutableData.willBeginStreamDidRun } }
        var didFinishStreamDidRun: Bool { get async { await self.mutableData.didFinishStreamDidRun } }
        var capturedWillSendUrlRequest: URLRequest? { get async { await self.mutableData.capturedWillSendUrlRequest } }
        var capturedDidReceiveData: Data? { get async { await self.mutableData.capturedDidReceiveData } }
        var capturedDidReceiveUrlResponse: URLResponse? { get async { await self.mutableData.capturedDidReceiveUrlResponse } }
        var capturedDidFailUrlRequest: URLRequest? { get async { await self.mutableData.capturedDidFailUrlRequest } }
        var capturedDidFailError: Error? { get async { await self.mutableData.capturedDidFailError } }
        var capturedWillBeginStreamUrlRequest: URLRequest? { get async { await self.mutableData.capturedWillBeginStreamUrlRequest } }
        var capturedWillBeginStreamUrlResponse: URLResponse? { get async { await self.mutableData.capturedWillBeginStreamUrlResponse } }
        var capturedDidFinishStreamUrlRequest: URLRequest? { get async { await self.mutableData.capturedDidFinishStreamUrlRequest } }
        var capturedDidFinishStreamUrlResponse: URLResponse? { get async { await self.mutableData.capturedDidFinishStreamUrlResponse } }
        var capturedDidFinishStreamError: Error? { get async { await self.mutableData.capturedDidFinishStreamError } }
        var willSendCallCount: Int { get async { await self.mutableData.willSendCallCount } }
        var didReceiveCallCount: Int { get async { await self.mutableData.didReceiveCallCount } }
        var didFailCallCount: Int { get async { await self.mutableData.didFailCallCount } }
        var willBeginStreamCallCount: Int { get async { await self.mutableData.willBeginStreamCallCount } }
        var didFinishStreamCallCount: Int { get async { await self.mutableData.didFinishStreamCallCount } }
        var eventLog: [String] { get async { await self.mutableData.eventLog } }

        init() {}

        func willSend(urlRequest: URLRequest) async {
            await self.mutableData.recordWillSend(urlRequest: urlRequest)
        }

        func didReceive(data: Data, urlResponse: URLResponse) async {
            await self.mutableData.recordDidReceive(data: data, urlResponse: urlResponse)
        }

        func didFail(urlRequest: URLRequest, dueTo error: Error) async {
            await self.mutableData.recordDidFail(urlRequest: urlRequest, error: error)
        }

        func willBeginStream(urlRequest: URLRequest, urlResponse: URLResponse) async {
            await self.mutableData.recordWillBeginStream(urlRequest: urlRequest, urlResponse: urlResponse)
        }

        func didFinishStream(urlRequest: URLRequest, urlResponse: URLResponse, error: Error?) async {
            await self.mutableData.recordDidFinishStream(urlRequest: urlRequest, urlResponse: urlResponse, error: error)
        }
    }
}
