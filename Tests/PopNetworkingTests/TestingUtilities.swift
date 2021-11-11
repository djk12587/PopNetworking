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

    init(responseSerializer: MockResponseSerializer = MockResponseSerializer()) {
        self.responseSerializer = responseSerializer
    }

    let baseUrl: String = "https://mockUrl.com"
    let path: String = ""
    let method: NetworkingRouteHttpMethod = .get
    let parameterEncoding: NetworkingRequestParameterEncoding = .url(params: nil)
    let responseSerializer: MockResponseSerializer
}

class MockResponseSerializer: NetworkingResponseSerializer {

    let serializedResult: Result<Void, Error>?
    let serializedResults: [Result<Void, Error>]
    private var serializeCounter = 0

    init(_ serializedResult: Result<Void, Error>) {
        self.serializedResult = serializedResult
        serializedResults = []
    }

    init(_ serializedResults: [Result<Void, Error>] = []) {
        self.serializedResults = serializedResults
        serializedResult = nil
    }

    func serialize(responseData: Data?, urlResponse: HTTPURLResponse?, responseError: Error?) -> Result<Void, Error> {
        defer { serializeCounter += 1 }

        if let serializedResult = serializedResult {
            return serializedResult
        }
        else if serializeCounter < serializedResults.count {
            return serializedResults[serializeCounter]
        }
        else {
            return .failure(responseError ?? NSError(domain: "Missing a mocked serialized response", code: 0))
        }
    }
}
