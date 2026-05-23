//
//  NetworkingResponseRouteTests.swift
//
//
//  Created by Dan_Koza on 2/16/22.
//

import XCTest
@testable import PopNetworking

class NetworkingResponseRouteTests: XCTestCase {

    func testCancellingNetworkingResponseRoute() async throws {
        let task = Task {
            try await ResponseRoute(baseUrl: "www.thisRequestWillBeCancelled.com",
                                    serializer: NetworkingSerializers.Response.Data()).run
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
        let urlRequest = try await ResponseRoute(baseUrl: "www.mockedExample.com",
                                         headers: headers,
                                         serializer: NetworkingSerializers.Response.HttpStatusCode()).urlRequest

        XCTAssertEqual(urlRequest.allHTTPHeaderFields, headers)
    }

    func testRouteHeaderOverridesParameterEncodingHeader() async throws {
        let urlRequest = try await ResponseRoute(baseUrl: "www.mockedExample.com",
                                         headers: ["Content-Type": "application/vnd.api+json"],
                                         parameterEncoding: .json(params: ["key": "value"]),
                                         serializer: NetworkingSerializers.Response.HttpStatusCode()).urlRequest

        XCTAssertEqual(urlRequest.value(forHTTPHeaderField: "Content-Type"), "application/vnd.api+json")
    }

}
