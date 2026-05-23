//
//  EmptyResponseSerializerTests.swift
//

import XCTest
@testable import PopNetworking

class EmptyResponseSerializerTests: XCTestCase {

    func testSuccessWithEmptyBody() async throws {
        let result = await Mock.ResponseRoute(session: NetworkingSession(urlSession: Mock.UrlSession(mockResult: .success(Data()))),
                                              serializer: NetworkingSerializers.Response.Empty()).task().result
        XCTAssertNoThrow(try result.get())
    }

    func testSuccessIgnoresNonEmptyBody() async throws {
        let mockData = "ignored".data(using: .utf8)!
        let result = await Mock.ResponseRoute(session: NetworkingSession(urlSession: Mock.UrlSession(mockResult: .success(mockData))),
                                              serializer: NetworkingSerializers.Response.Empty()).task().result
        XCTAssertNoThrow(try result.get())
    }

    func testNetworkingFailure() async throws {
        let mockNetworkingResponseError = NSError(domain: "mock error", code: 1)
        let result = await Mock.ResponseRoute(session: NetworkingSession(urlSession: Mock.UrlSession(mockResult: .failure(mockNetworkingResponseError))),
                                              serializer: NetworkingSerializers.Response.Empty()).task().result
        XCTAssertThrowsError(try result.get()) { error in
            XCTAssertEqual(mockNetworkingResponseError, error as NSError)
        }
    }

    func testHeadRequestDispatchesAsHead() async throws {
        let urlSession = Mock.UrlSession(mockResult: .success(Data()))
        let result = await Mock.ResponseRoute(method: .head,
                                              session: NetworkingSession(urlSession: urlSession),
                                              serializer: NetworkingSerializers.Response.Empty()).task().result

        XCTAssertNoThrow(try result.get())
        let dispatched = await urlSession.lastRequest
        XCTAssertEqual(dispatched?.httpMethod, "HEAD")
    }

    func testOptionsRequestDispatchesAsOptions() async throws {
        let urlSession = Mock.UrlSession(mockResult: .success(Data()))
        let result = await Mock.ResponseRoute(method: .options,
                                              session: NetworkingSession(urlSession: urlSession),
                                              serializer: NetworkingSerializers.Response.Empty()).task().result

        XCTAssertNoThrow(try result.get())
        let dispatched = await urlSession.lastRequest
        XCTAssertEqual(dispatched?.httpMethod, "OPTIONS")
    }
}
