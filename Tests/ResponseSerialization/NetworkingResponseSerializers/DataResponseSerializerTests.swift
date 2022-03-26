//
//  DataResponseSerializerTests.swift
//  
//
//  Created by Dan Koza on 12/6/21.
//

import XCTest
@testable import PopNetworking

class DataResponseSerializerTests: XCTestCase {

    func testSuccess() async throws {

        let mockData = "mock Data".data(using: .utf8)
        let responseData = try await Mock.Route(session: NetworkingSession(urlSession: Mock.UrlSession(mockResponseData: mockData)),
                                                responseSerializer: .data).task().result.get()
        XCTAssertEqual(responseData, mockData)
    }

    func testNilResponse() async throws {
        let result = await Mock.Route(session: NetworkingSession(urlSession: Mock.UrlSession()),
                                      responseSerializer: .data).task().result
        XCTAssertThrowsError(try result.get()) { error in
            XCTAssertEqual((error as NSError).code, URLError.cannotParseResponse.rawValue)
        }
    }

    func testNetworkingFailure() async throws {

        let mockNetworkingResponseError = NSError(domain: "mock error", code: 1)
        let responseResult = await Mock.Route(session: NetworkingSession(urlSession: Mock.UrlSession(mockResponseError: mockNetworkingResponseError)),
                                              responseSerializer: .data).task().result
        XCTAssertThrowsError(try responseResult.get()) { error in
            XCTAssertEqual(mockNetworkingResponseError, error as NSError)
        }
    }
}
