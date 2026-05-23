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

        let mockData = "mock Data".data(using: .utf8)!
        let responseData = try await Mock.ResponseRoute(session: NetworkingSession(urlSession: Mock.UrlSession(mockResult: .success(mockData))),
                                                        serializer: NetworkingSerializers.Response.Data()).task().result.get()
        XCTAssertEqual(responseData, mockData)
    }

    func testNetworkingFailure() async throws {

        let mockNetworkingResponseError = NSError(domain: "mock error", code: 1)
        let responseResult = await Mock.ResponseRoute(session: NetworkingSession(urlSession: Mock.UrlSession(mockResult:.failure(mockNetworkingResponseError))),
                                                      serializer: NetworkingSerializers.Response.Data()).task().result
        XCTAssertThrowsError(try responseResult.get()) { error in
            XCTAssertEqual(mockNetworkingResponseError, error as NSError)
        }
    }
}
