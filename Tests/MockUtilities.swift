//
//  File.swift
//  
//
//  Created by Dan_Koza on 11/11/21.
//

import Foundation
@testable import PopNetworking

enum Mock {

    struct Route<ResponseSerializer: NetworkingResponseSerializer>: NetworkingRoute {

        var baseUrl: String
        var path: String
        var method: NetworkingRouteHttpMethod
        var parameterEncoding: NetworkingRouteParameterEncoding?
        var session: NetworkingSessionProtocol
        var responseValidator: NetworkingResponseValidator?
        var responseSerializer: ResponseSerializer
        var mockSerializedResult: Result<ResponseSerializer.SerializedObject, Error>?
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
             responseValidator: NetworkingResponseValidator? = nil,
             responseSerializer: ResponseSerializer,
             timeoutInterval: TimeInterval? = nil,
             mockSerializedResult: Result<ResponseSerializer.SerializedObject, Error>? = nil,
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
            self.responseValidator = responseValidator
            self.responseSerializer = responseSerializer
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
        var lastRequest: URLRequest? {
            get async { await self.mutableData.lastRequest }
        }

        init(mockResult: Result<Data, Error> = .success(Data()),
             mockUrlResponse: URLResponse? = nil,
             mockDelay: TimeInterval? = nil) {
            self.mockResult = mockResult
            self.mockUrlResponse = mockUrlResponse
            self.mockDelay = mockDelay
        }

        func data(for request: URLRequest) async throws -> (Data, URLResponse) {
            try? await Task.sleep(nanoseconds: UInt64(mockDelay ?? 0) * 1_000_000_000)
            await self.mutableData.set(lastRequest: request)
            return (try mockResult.get(), self.mockUrlResponse ?? URLResponse())
        }

        func data(for request: URLRequest, delegate: URLSessionTaskDelegate?) async throws -> (Data, URLResponse) {
            try await self.data(for: request)
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
        var lastRequest: URLRequest? {
            get async { await self.mutableData.lastRequest }
        }

        init(mockResults: [Result<Data, Error>], mockUrlResponses: [URLResponse?] = []) {
            self.mockResults = mockResults
            self.mockUrlResponses = mockUrlResponses
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
    }

    struct ResponseSerializer<SuccessType: Sendable>: NetworkingResponseSerializer {

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

    struct ResponseSerializers<SuccessType: Sendable>: NetworkingResponseSerializer {

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

    struct ResponseValidator: NetworkingResponseValidator {
        let mockValidationError: Error?

        init(mockValidationError: Error?) {
            self.mockValidationError = mockValidationError
        }
        
        func validate(responseResult: Result<(Data, URLResponse), Error>) throws {
            guard let mockValidationError = mockValidationError else { return }
            throw mockValidationError
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
            var capturedWillSendUrlRequest: URLRequest?
            var capturedDidReceiveData: Data?
            var capturedDidReceiveUrlResponse: URLResponse?
            var capturedDidFailUrlRequest: URLRequest?
            var capturedDidFailError: Error?
            var willSendCallCount = 0
            var didReceiveCallCount = 0
            var didFailCallCount = 0

            func recordWillSend(urlRequest: URLRequest) {
                self.willSendDidRun = true
                self.capturedWillSendUrlRequest = urlRequest
                self.willSendCallCount += 1
            }

            func recordDidReceive(data: Data, urlResponse: URLResponse) {
                self.didReceiveDidRun = true
                self.capturedDidReceiveData = data
                self.capturedDidReceiveUrlResponse = urlResponse
                self.didReceiveCallCount += 1
            }

            func recordDidFail(urlRequest: URLRequest, error: Error) {
                self.didFailDidRun = true
                self.capturedDidFailUrlRequest = urlRequest
                self.capturedDidFailError = error
                self.didFailCallCount += 1
            }
        }

        private let mutableData = SafeMutableData()

        var willSendDidRun: Bool { get async { await self.mutableData.willSendDidRun } }
        var didReceiveDidRun: Bool { get async { await self.mutableData.didReceiveDidRun } }
        var didFailDidRun: Bool { get async { await self.mutableData.didFailDidRun } }
        var capturedWillSendUrlRequest: URLRequest? { get async { await self.mutableData.capturedWillSendUrlRequest } }
        var capturedDidReceiveData: Data? { get async { await self.mutableData.capturedDidReceiveData } }
        var capturedDidReceiveUrlResponse: URLResponse? { get async { await self.mutableData.capturedDidReceiveUrlResponse } }
        var capturedDidFailUrlRequest: URLRequest? { get async { await self.mutableData.capturedDidFailUrlRequest } }
        var capturedDidFailError: Error? { get async { await self.mutableData.capturedDidFailError } }
        var willSendCallCount: Int { get async { await self.mutableData.willSendCallCount } }
        var didReceiveCallCount: Int { get async { await self.mutableData.didReceiveCallCount } }
        var didFailCallCount: Int { get async { await self.mutableData.didFailCallCount } }

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
    }
}
