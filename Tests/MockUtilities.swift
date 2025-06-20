//
//  File.swift
//  
//
//  Created by Dan_Koza on 11/11/21.
//

import Foundation
@testable import PopNetworking

enum Mock {

    struct Route<ResponseSerializer: NetworkingResponseSerializer & Sendable>: NetworkingRoute {

        var baseUrl: String
        var path: String
        var method: NetworkingRouteHttpMethod
        var parameterEncoding: NetworkingRequestParameterEncoding?
        var session: NetworkingSession
        var responseValidator: NetworkingResponseValidator?
        var responseSerializer: ResponseSerializer
        var timeoutInterval: TimeInterval?
        var repeater: Repeater?

        init(baseUrl: String = "https://mockUrl.com",
             path: String = "",
             method: NetworkingRouteHttpMethod = .get,
             parameterEncoding: NetworkingRequestParameterEncoding? = nil,
             session: NetworkingSession = NetworkingSession(urlSession: Mock.UrlSession()),
             responseValidator: NetworkingResponseValidator? = nil,
             responseSerializer: ResponseSerializer,
             timeoutInterval: TimeInterval? = nil,
             repeater: Repeater? = nil) {
            self.baseUrl = baseUrl
            self.path = path
            self.method = method
            self.parameterEncoding = parameterEncoding
            self.session = session
            self.responseValidator = responseValidator
            self.responseSerializer = responseSerializer
            self.timeoutInterval = timeoutInterval
            self.repeater = repeater
        }
    }

    final actor UrlSession: URLSessionProtocol {

        let mockResult: Result<Data, Error>
        let mockUrlResponse: URLResponse?
        let mockDelay: TimeInterval?

        private(set) var lastRequest: URLRequest?

        init(mockResult: Result<Data, Error> = .success(Data()),
             mockUrlResponse: URLResponse? = nil,
             mockDelay: TimeInterval? = nil) {
            self.mockResult = mockResult
            self.mockUrlResponse = mockUrlResponse
            self.mockDelay = mockDelay
        }

        func data(for request: URLRequest) async throws -> (Data, URLResponse) {
            defer { lastRequest = request }
            try? await Task.sleep(nanoseconds: UInt64(mockDelay ?? 0) * 1_000_000_000)
            return (try mockResult.get(), self.mockUrlResponse ?? URLResponse())
        }

        func data(for request: URLRequest, delegate: URLSessionTaskDelegate?) async throws -> (Data, URLResponse) {
            try await data(for: request)
        }
    }

    struct ResponseSerializer<SuccessType: Sendable>: NetworkingResponseSerializer {

        let serializedResult: Result<SuccessType, Error>

        init(_ serializedResult: Result<SuccessType, Error> = .success(())) {
            self.serializedResult = serializedResult
        }

        func serialize(result: Result<Data, Error>, urlResponse: HTTPURLResponse?) async -> Result<SuccessType, Error> {
            switch result {
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

        func serialize(result: Result<Data, Error>, urlResponse: HTTPURLResponse?) async -> Result<SuccessType, Error> {
            let index = await self.index.value
            await self.index.updateIndex()
            guard index < self.serializedResults.count else { fatalError("out of bounds: index > serializedResults.count") }
            switch result {
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
        
        func validate(result: Result<Data, Error>, urlResponse: HTTPURLResponse?) throws {
            guard let mockValidationError = mockValidationError else { return }
            throw mockValidationError
        }
    }

    actor RequestInterceptor: NetworkingRequestInterceptor {

        enum AdapterResult {
            case doNotAdapt
            case adapt(adaptedUrlRequest: URLRequest)
            case failure(error: Error)
        }

        init(adapterResult: AdapterResult,
             retrierResult: NetworkingRequestRetrierResult) {
            self.adapterResult = adapterResult
            self.retrierResult = retrierResult
        }

        var adapterDidRun = false
        var adapterResult: AdapterResult

        func adapt(urlRequest: URLRequest) async throws -> URLRequest {
            defer { adapterDidRun = true }

            switch adapterResult {
                case .doNotAdapt:
                    return urlRequest
                case .adapt(let adaptedUrlRequest):
                    return adaptedUrlRequest
                case .failure(let error):
                    throw error
            }
        }

        var retrierDidRun = false
        var retrierResult: NetworkingRequestRetrierResult
        var retrierPayload: (urlRequest: URLRequest?, error: Error, urlResponse: HTTPURLResponse?, retryCount: Int)?
        var retryCounter = 0

        func retry(urlRequest: URLRequest?, dueTo error: Error, urlResponse: HTTPURLResponse?, retryCount: Int) async -> NetworkingRequestRetrierResult {
            defer {
                retrierPayload = (urlRequest, error, urlResponse, retryCount)
                retrierDidRun = true
                retryCounter += 1
            }
            return retrierResult
        }
    }
}
