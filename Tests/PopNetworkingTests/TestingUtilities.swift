//
//  File.swift
//  
//
//  Created by Dan_Koza on 11/11/21.
//

import Foundation
@testable import PopNetworking

class MockUrlSession: URLSessionProtocol {

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

struct MockRoute<ResponseSuccessType>: NetworkingRoute {

    var baseUrl: String
    var path: String
    var method: NetworkingRouteHttpMethod
    var parameterEncoding: NetworkingRequestParameterEncoding
    var responseSerializer: MockResponseSerializer = MockResponseSerializer<ResponseSuccessType>()
    var session: NetworkingSession

    init(baseUrl: String = "https://mockUrl.com",
         path: String = "",
         method: NetworkingRouteHttpMethod = .get,
         parameterEncoding: NetworkingRequestParameterEncoding = .url(params: nil),
         responseSerializer: MockResponseSerializer<ResponseSuccessType> = MockResponseSerializer(),
         session: NetworkingSession = NetworkingSession(session: MockUrlSession())) {
        self.baseUrl = baseUrl
        self.path = path
        self.method = method
        self.parameterEncoding = parameterEncoding
        self.responseSerializer = responseSerializer
        self.session = session
    }
}

class MockResponseSerializer<SuccessType>: NetworkingResponseSerializer {

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

class MockRequestInterceptor: NetworkingRequestInterceptor {

    init(adapterResult: MockRequestInterceptor.MockAdapterResult,
         retrierResult: NetworkingRequestRetrierResult) {
        self.adapterResult = adapterResult
        self.retrierResult = retrierResult
    }

    var adapterDidRun = false
    var adapterResult: MockAdapterResult

    func adapt(urlRequest: URLRequest) async throws -> URLRequest {
        defer { adapterDidRun = true }

        switch adapterResult {
            case .doNotAdapt:
                return urlRequest
            case .adapted(let mockAdaptedUrlRequest):
                return mockAdaptedUrlRequest
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

extension MockRequestInterceptor {
    enum MockAdapterResult {
        case doNotAdapt
        case adapted(mockAdaptedUrlRequest: URLRequest)
        case failure(error: Error)
    }
}
