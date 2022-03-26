//
//  RetrierTests.swift
//  
//
//  Created by Dan Koza on 12/6/21.
//

import XCTest
@testable import PopNetworking

class RouteRetrierTests: XCTestCase {

    func testRetrierRetry() async {
        var numberOfRetries = 0
        _ = await Mock.Route(baseUrl: "base",
                             responseSerializer: .mock(.success("success")),
                             retrier: { _, _, retryCount in
            numberOfRetries = retryCount
            return retryCount > 1 ? .doNotRetry : .retry
        }).result

        XCTAssertEqual(numberOfRetries, 2)
    }

    func testRetrierRetryWithDelay() async {
        var numberOfRetries = 0
        _ = await Mock.Route(baseUrl: "base",
                             responseSerializer: .mock(.success("success")),
                             retrier: { _, _, retryCount in
            numberOfRetries = retryCount
            return retryCount > 0 ? .doNotRetry : .retryWithDelay(0)
        }).result

        XCTAssertEqual(numberOfRetries, 1)
    }

    func testRetrierDoNotRetry() async {
        var numberOfRetries = 0
        _ = await Mock.Route(baseUrl: "base",
                             responseSerializer: .mock(.success("success")),
                             retrier: { _, _, retryCount in
            numberOfRetries = retryCount
            return .doNotRetry
        }).result

        XCTAssertEqual(numberOfRetries, 0)
    }

    func testRetrierThrows() async {
        let mockError = NSError(domain: "mock Error", code: 1)
        let result = await Mock.Route(baseUrl: "base",
                                      responseSerializer: .mock(.success("success")),
                                      retrier: { _, _, _ in
            throw mockError
        }).result

        XCTAssertThrowsError(try result.get()) { error in
            XCTAssertEqual(mockError, error as NSError)
        }
    }

    func testRetrierParameters() async throws {
        _ = await Mock.Route(baseUrl: "base",
                             session: NetworkingSession(urlSession: Mock.UrlSession(mockUrlResponse: HTTPURLResponse())),
                             responseSerializer: .mock(.success("success")),
                             retrier: { result, response, retryCount in
            XCTAssertEqual(try result.get(), "success")
            XCTAssertNotNil(response)
            XCTAssertEqual(retryCount, 0)
            return .doNotRetry
        }).result
    }
}
