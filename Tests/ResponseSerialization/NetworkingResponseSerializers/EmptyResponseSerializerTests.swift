//
//  EmptyResponseSerializerTests.swift
//

import XCTest
@testable import PopNetworking

class EmptyResponseSerializerTests: XCTestCase {

    func testSuccessWithEmptyBody() async throws {
        let result = await Mock.Route(session: NetworkingSession(urlSession: Mock.UrlSession(mockResult: .success(Data()))),
                                      responseSerializer: NetworkingResponseSerializers.EmptyResponseSerializer()).task().result
        XCTAssertNoThrow(try result.get())
    }

    func testSuccessIgnoresNonEmptyBody() async throws {
        let mockData = "ignored".data(using: .utf8)!
        let result = await Mock.Route(session: NetworkingSession(urlSession: Mock.UrlSession(mockResult: .success(mockData))),
                                      responseSerializer: NetworkingResponseSerializers.EmptyResponseSerializer()).task().result
        XCTAssertNoThrow(try result.get())
    }

    func testNetworkingFailure() async throws {
        let mockNetworkingResponseError = NSError(domain: "mock error", code: 1)
        let result = await Mock.Route(session: NetworkingSession(urlSession: Mock.UrlSession(mockResult: .failure(mockNetworkingResponseError))),
                                      responseSerializer: NetworkingResponseSerializers.EmptyResponseSerializer()).task().result
        XCTAssertThrowsError(try result.get()) { error in
            XCTAssertEqual(mockNetworkingResponseError, error as NSError)
        }
    }

    func testHeadRequestDispatchesAsHead() async throws {
        let urlSession = Mock.UrlSession(mockResult: .success(Data()))
        let result = await Mock.Route(method: .head,
                                      session: NetworkingSession(urlSession: urlSession),
                                      responseSerializer: NetworkingResponseSerializers.EmptyResponseSerializer()).task().result

        XCTAssertNoThrow(try result.get())
        let dispatched = await urlSession.lastRequest
        XCTAssertEqual(dispatched?.httpMethod, "HEAD")
    }

    func testOptionsRequestDispatchesAsOptions() async throws {
        let urlSession = Mock.UrlSession(mockResult: .success(Data()))
        let result = await Mock.Route(method: .options,
                                      session: NetworkingSession(urlSession: urlSession),
                                      responseSerializer: NetworkingResponseSerializers.EmptyResponseSerializer()).task().result

        XCTAssertNoThrow(try result.get())
        let dispatched = await urlSession.lastRequest
        XCTAssertEqual(dispatched?.httpMethod, "OPTIONS")
    }
}
