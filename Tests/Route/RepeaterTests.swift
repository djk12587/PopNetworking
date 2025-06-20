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
        let expectation = expectation(description: "wait for repeater to finish")
        _ = await Mock.Route(baseUrl: "base",
                             responseSerializer: Mock.ResponseSerializer(.success("success")),
                             repeater: { _, _, repeatCount in
            let retrierResult: NetworkingRequestRetrierResult = repeatCount > 1 ? .doNotRetry : .retry
            if case .doNotRetry = retrierResult, repeatCount == 2 {
                expectation.fulfill()
            }
            return retrierResult
        }).result

        await fulfillment(of: [expectation], timeout: 1.0)
    }

    func testRepeaterRetryWithDelay() async {
        let expectation = expectation(description: "wait for repeater to finish")
        _ = await Mock.Route(baseUrl: "base",
                             responseSerializer: Mock.ResponseSerializer(.success("success")),
                             repeater: { _, _, repeatCount in
            let retrierResult: NetworkingRequestRetrierResult = repeatCount > 0 ? .doNotRetry : .retryWithDelay(0)
            if case .doNotRetry = retrierResult, repeatCount == 1 {
                expectation.fulfill()
            }
            return retrierResult
        }).result

        await fulfillment(of: [expectation], timeout: 1.0)
    }

    func testRepeaterDoNotRetry() async {
        let expectation = expectation(description: "wait for repeater to finish")
        _ = await Mock.Route(baseUrl: "base",
                             responseSerializer: Mock.ResponseSerializer(.success("success")),
                             repeater: { _, _, repeatCount in
            if repeatCount == 0 {
                expectation.fulfill()
            }
            return .doNotRetry
        }).result

        await fulfillment(of: [expectation], timeout: 1.0)
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
