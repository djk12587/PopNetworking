//
//  NetworkingRouteTests.swift
//  
//
//  Created by Dan_Koza on 2/16/22.
//

import XCTest
@testable import PopNetworking

class NetworkingRouteTests: XCTestCase {

    func testCancellingNetworkingRoute() async throws {
        let task = Task {
            try await Route(baseUrl: "www.thisRequestWillBeCancelled.com",
                            responseSerializer: NetworkingResponseSerializers.DataResponseSerializer()).run
        }
        task.cancel()
        do {
            _ = try await task.value
            XCTFail("a cancellation error should be thrown")
        } catch {
            XCTAssertEqual((error as NSError).code, URLError.cancelled.rawValue)
        }
    }

    func testHeadersAddedToUrlRequest() async throws {
        let headers = ["headerKey1": "headerValue1",
                       "headerKey2": "headerValue2"]
        let urlRequest = try Route(baseUrl: "www.mockedExample.com",
                                   headers: headers,
                                   responseSerializer: NetworkingResponseSerializers.HttpStatusCodeResponseSerializer()).urlRequest

        XCTAssertEqual(urlRequest.allHTTPHeaderFields, headers)
    }

    func testMockResponse() async throws {
        let mockValue = try await Route(baseUrl: "www.mockedExample.com",
                                        responseSerializer: NetworkingResponseSerializers.HttpStatusCodeResponseSerializer(),
                                        mockSerializedResult: .success(123)).run

        XCTAssertEqual(mockValue, 123)
    }

    func testInvalidUrlThrowsError() async throws {
        let result = await Route(baseUrl: "",
                                 responseSerializer: NetworkingResponseSerializers.HttpStatusCodeResponseSerializer()).result

        XCTAssertThrowsError(try result.get(), "we expect an invalid url error") { error in
            XCTAssertEqual((error as? URLError)?.code, .badURL)
        }
    }
}
