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
        var parameterEncoding: NetworkingRequestParameterEncoding?
        var session: NetworkingSessionProtocol
        var responseValidator: NetworkingResponseValidator?
        var responseSerializer: ResponseSerializer
        var mockSerializedResult: Result<ResponseSerializer.SerializedObject, Error>?
        var timeoutInterval: TimeInterval?
        var repeater: Repeater?

        init(baseUrl: String = "https://mockUrl.com",
             path: String = "",
             method: NetworkingRouteHttpMethod = .get,
             parameterEncoding: NetworkingRequestParameterEncoding? = nil,
             session: NetworkingSessionProtocol = NetworkingSession(urlSession: Mock.UrlSession()),
             responseValidator: NetworkingResponseValidator? = nil,
             responseSerializer: ResponseSerializer,
             timeoutInterval: TimeInterval? = nil,
             mockSerializedResult: Result<ResponseSerializer.SerializedObject, Error>? = nil,
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

    struct RequestInterceptor: NetworkingRouteInterceptor {

        enum AdapterResult {
            case doNotAdapt
            case adapt(adaptedUrlRequest: URLRequest)
            case failure(error: Error)
        }

        private actor SafeMutableData {

            var adapterDidRun = false
            var adapterResult: AdapterResult
            var retrierDidRun = false
            var retrierResult: NetworkingRouteRetrierResult
            var retrierPayload: (urlRequest: URLRequest?, error: Error, urlResponse: URLResponse?, retryCount: Int)?
            var retryCounter = 0

            init(adapterDidRun: Bool = false, adapterResult: AdapterResult, retrierDidRun: Bool = false, retrierResult: NetworkingRouteRetrierResult, retrierPayload: (urlRequest: URLRequest?, error: Error, urlResponse: HTTPURLResponse?, retryCount: Int)? = nil, retryCounter: Int = 0) {
                self.adapterDidRun = adapterDidRun
                self.adapterResult = adapterResult
                self.retrierDidRun = retrierDidRun
                self.retrierResult = retrierResult
                self.retrierPayload = retrierPayload
                self.retryCounter = retryCounter
            }

            func set(adapterDidRun: Bool) {
                self.adapterDidRun = adapterDidRun
            }

            func set(adapterResult: AdapterResult) {
                self.adapterResult = adapterResult
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
        }

        private let mutableData: SafeMutableData
        var adapterDidRun: Bool { get async { await self.mutableData.adapterDidRun } }
        var retrierDidRun: Bool { get async { await self.mutableData.retrierDidRun } }
        var retryCounter: Int { get async { await self.mutableData.retryCounter } }

        init(adapterResult: AdapterResult,
             retrierResult: NetworkingRouteRetrierResult) {
            self.mutableData = SafeMutableData(adapterResult: adapterResult, retrierResult: retrierResult)
        }

        func adapt(urlRequest: URLRequest) async throws -> URLRequest {
            await self.mutableData.set(adapterDidRun: true)

            switch await self.mutableData.adapterResult {
                case .doNotAdapt:
                    return urlRequest
                case .adapt(let adaptedUrlRequest):
                    return adaptedUrlRequest
                case .failure(let error):
                    throw error
            }
        }

        func retry(urlRequest: URLRequest?, dueTo error: any Error, urlResponse: URLResponse?, retryCount: Int) async -> NetworkingRouteRetrierResult {
            await self.mutableData.set(retrierPayload: (urlRequest, error, urlResponse, retryCount))
            await self.mutableData.set(retrierDidRun: true)
            await self.mutableData.set(retryCounter: await self.mutableData.retryCounter + 1)
            return await self.mutableData.retrierResult
        }

    }
}
