//
//  RepeaterTests.swift
//  
//
//  Created by Dan Koza on 12/6/21.
//

import XCTest
@testable import PopNetworking

class RepeaterTests: XCTestCase {

    func testRepeaterRetry() async {
        var numberOfRetries = 0
        _ = await Mock.Route(baseUrl: "base",
                             responseSerializer: Mock.ResponseSerializer(.success("success")),
                             repeater: { _, _, repeatCount in
            numberOfRetries = repeatCount
            return repeatCount > 1 ? .doNotRetry : .retry
        }).result

        XCTAssertEqual(numberOfRetries, 2)
    }

    func testRepeaterRetryWithDelay() async {
        var numberOfRetries = 0
        _ = await Mock.Route(baseUrl: "base",
                             responseSerializer: Mock.ResponseSerializer(.success("success")),
                             repeater: { _, _, repeatCount in
            numberOfRetries = repeatCount
            return repeatCount > 0 ? .doNotRetry : .retryWithDelay(0)
        }).result

        XCTAssertEqual(numberOfRetries, 1)
    }

    func testRepeaterDoNotRetry() async {
        var numberOfRetries = 0
        _ = await Mock.Route(baseUrl: "base",
                             responseSerializer: Mock.ResponseSerializer(.success("success")),
                             repeater: { _, _, repeatCount in
            numberOfRetries = repeatCount
            return .doNotRetry
        }).result

        XCTAssertEqual(numberOfRetries, 0)
    }

    func testRepeaterParameters() async throws {
        _ = try await Mock.Route(baseUrl: "base",
                                 session: NetworkingSession(urlSession: Mock.UrlSession(mockUrlResponse: HTTPURLResponse())),
                                 responseSerializer: Mock.ResponseSerializer(.success("success")),
                                 repeater: { result, response, repeatCount in
            XCTAssertEqual(try? result.get(), "success")
            XCTAssertNotNil(response)
            XCTAssertEqual(repeatCount, 0)
            return .doNotRetry
        }).result.get()
    }

    func testRepeaterCancellation() async throws {
        let routeTask = Route(baseUrl: "www.thisRequestWillBeCancelled.com",
                              responseSerializer: NetworkingResponseSerializers.DataResponseSerializer(),
                              repeater: { result, response, repeatCount in
            XCTAssertEqual((result.error as? NSError)?.code, URLError.cancelled.rawValue)
            return .doNotRetry
        }).task()

        routeTask.cancel()

        do {
            _ = try await routeTask.value
            XCTFail("routeTask.value should throw a cancellation error")
        } catch {
            XCTAssertEqual((error as NSError).code, URLError.cancelled.rawValue)
        }
    }
}
