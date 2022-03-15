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
        var session: NetworkingSession
        var responseSerializer: ResponseSerializer
        var retrier: Retrier?

        init(baseUrl: String = "https://mockUrl.com",
             path: String = "",
             method: NetworkingRouteHttpMethod = .get,
             parameterEncoding: NetworkingRequestParameterEncoding? = .url(params: nil),
             session: NetworkingSession = NetworkingSession(urlSession: Mock.UrlSession()),
             responseSerializer: ResponseSerializer,
             retrier: Retrier? = nil) {
            self.baseUrl = baseUrl
            self.path = path
            self.method = method
            self.parameterEncoding = parameterEncoding
            self.session = session
            self.responseSerializer = responseSerializer
            self.retrier = retrier
        }
    }

    class UrlSession: URLSessionProtocol {

        var mockResponseData: Data?
        var mockUrlResponse: URLResponse?
        var mockResponseError: Error?

        private(set) var lastRequest: URLRequest?

        init(mockResponseData: Data? = nil, mockUrlResponse: URLResponse? = nil, mockResponseError: Error? = nil) {
            self.mockResponseData = mockResponseData
            self.mockUrlResponse = mockUrlResponse
            self.mockResponseError = mockResponseError
        }

        func dataTask(with request: URLRequest, completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void) -> URLSessionDataTask {
            defer { lastRequest = request }
            completionHandler(mockResponseData, mockUrlResponse, mockResponseError)
            return URLSession(configuration: .default).dataTask(with: request) //This dataTask is useless, its only used because we have to return an instance of `URLSessionDataTask`
        }
    }

    class ResponseSerializer<SuccessType>: NetworkingResponseSerializer {

        var serializedResult: Result<SuccessType, Error>?
        var sequentialResults: [Result<SuccessType, Error>]
        var payload: (responseData: Data?, urlResponse: HTTPURLResponse?, responseError: Error?)?

        init(_ serializedResult: Result<SuccessType, Error>) {
            self.serializedResult = serializedResult
            sequentialResults = []
        }

        init(_ sequentialResults: [Result<SuccessType, Error>] = []) {
            self.sequentialResults = sequentialResults
            serializedResult = nil
        }

        func serialize(responseData: Data?, urlResponse: HTTPURLResponse?, responseError: Error?) -> Result<SuccessType, Error> {
            defer { payload = (responseData, urlResponse, responseError) }

            if let serializedResult = serializedResult {
                return serializedResult
            }
            else if let sequentialResult = sequentialResults.first {
                sequentialResults.removeFirst()
                return sequentialResult
            }
            else {
                return .failure(responseError ?? NSError(domain: "Missing a mocked serialized response", code: 0))
            }
        }
    }

    class RequestInterceptor: NetworkingRequestInterceptor {

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
