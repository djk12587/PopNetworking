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

    init(mockResponseData: Data? = nil, mockUrlResponse: URLResponse? = nil, mockResponseError: Error? = nil) {
        self.mockResponseData = mockResponseData
        self.mockUrlResponse = mockUrlResponse
        self.mockResponseError = mockResponseError
    }

    func dataTask(with request: URLRequest, completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void) -> URLSessionDataTask {
        completionHandler(mockResponseData, mockUrlResponse, mockResponseError)
        return URLSession(configuration: .default).dataTask(with: request) //This dataTask is useless, its only used because we have to return an instance of `URLSessionDataTask`
    }
}

struct MockRoute: NetworkingRoute {

    var baseUrl: String
    var path: String
    var method: NetworkingRouteHttpMethod
    var parameterEncoding: NetworkingRequestParameterEncoding
    var responseSerializer: MockResponseSerializer = MockResponseSerializer()
    var session: NetworkingSession

    init(baseUrl: String = "https://mockUrl.com",
         path: String = "",
         method: NetworkingRouteHttpMethod = .get,
         parameterEncoding: NetworkingRequestParameterEncoding = .url(params: nil),
         responseSerializer: MockResponseSerializer = MockResponseSerializer(),
         session: NetworkingSession = NetworkingSession(session: MockUrlSession(mockResponseData: nil,
                                                                                mockUrlResponse: nil,
                                                                                mockResponseError: nil))) {
        self.baseUrl = baseUrl
        self.path = path
        self.method = method
        self.parameterEncoding = parameterEncoding
        self.responseSerializer = responseSerializer
        self.session = session
    }
}

class MockResponseSerializer: NetworkingResponseSerializer {

    var serializedResult: Result<Void, Error>?
    var sequentialResults: [Result<Void, Error>]

    init(_ serializedResult: Result<Void, Error>) {
        self.serializedResult = serializedResult
        sequentialResults = []
    }

    init(_ sequentialResults: [Result<Void, Error>] = []) {
        self.sequentialResults = sequentialResults
        serializedResult = nil
    }

    func serialize(responseData: Data?, urlResponse: HTTPURLResponse?, responseError: Error?) -> Result<Void, Error> {
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
