//
//  HttpStatusCodeResponseSerializerTests.swift
//  
//
//  Created by Dan Koza on 12/6/21.
//

import XCTest
@testable import PopNetworking

class HttpStatusCodeResponseSerializerTests: XCTestCase {

    func testSuccess() async throws {

        let mockResponse = HTTPURLResponse(url: URL(string: "https://mockurl.com")!, statusCode: 200, httpVersion: nil, headerFields: nil)
        let responseStatusCode = try await Mock.Route(session: NetworkingSession(urlSession: Mock.UrlSession(mockUrlResponse: mockResponse)),
                                                      responseSerializer: NetworkingResponseSerializers.HttpStatusCodeResponseSerializer()).task().result.get()

        XCTAssertEqual(mockResponse?.statusCode, responseStatusCode)
    }

    func testNilResponse() async throws {

        let result = await Mock.Route(session: NetworkingSession(urlSession: Mock.UrlSession()),
                                      responseSerializer: NetworkingResponseSerializers.HttpStatusCodeResponseSerializer()).task().result
        XCTAssertThrowsError(try result.get()) { error in
            XCTAssertEqual((error as NSError).code, URLError.badServerResponse.rawValue)
        }
    }

    func testNetworkingFailure() async throws {

        let mockNetworkingResponseError = NSError(domain: "mock error", code: 1)
        let responseResult = await Mock.Route(session: NetworkingSession(urlSession: Mock.UrlSession(mockResult: .failure(mockNetworkingResponseError))),
                                              responseSerializer: NetworkingResponseSerializers.HttpStatusCodeResponseSerializer()).task().result
        XCTAssertThrowsError(try responseResult.get()) { error in
            XCTAssertEqual(mockNetworkingResponseError, error as NSError)
        }
    }
}
