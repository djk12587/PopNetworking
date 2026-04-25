//
//  RepeaterTests.swift
//  
//
//  Created by Dan Koza on 12/6/21.
//

import XCTest
@testable import PopNetworking

class RepeaterTests: XCTestCase {

    private actor Counter {
        private(set) var value = 0
        func increment() { value += 1 }
    }

    func testRepeaterRetry() async {
        let expectation = expectation(description: "wait for repeater to finish")
        _ = await Mock.Route(baseUrl: "base",
                             responseSerializer: Mock.ResponseSerializer(.success("success")),
                             repeater: { _, _, _, repeatCount  in
            let retrierResult: NetworkingRetrierResult = repeatCount > 1 ? .doNotRetry : .retry
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
                             repeater: { _, _, _, repeatCount in
            let retrierResult: NetworkingRetrierResult = repeatCount > 0 ? .doNotRetry : .retryWithDelay(0)
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
                             repeater: { _, _, _, repeatCount in
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
                                 repeater: { result, request, response, repeatCount in
            XCTAssertEqual(try? result.get(), "success")
            XCTAssertNotNil(request)
            XCTAssertNotNil(response)
            XCTAssertEqual(repeatCount, 0)
            return .doNotRetry
        }).result.get()
    }

    func testRepeaterCancellation() async throws {
        let routeTask = Route(baseUrl: "www.thisRequestWillBeCancelled.com",
                              responseSerializer: NetworkingResponseSerializers.DataResponseSerializer(),
                              repeater: { result, _, _, _ in
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
    
    func testRepeaterIsInvokedExactlyOnceWhenRetrierTriggersRetry() async throws {
        let mockRetrier = Mock.Interceptor(retrierResult: .retryWithDelay(0))
        let repeaterInvocations = Counter()

        _ = await Mock.Route(
            session: NetworkingSession(urlSession: Mock.UrlSession()),
            responseSerializer: Mock.ResponseSerializers<Void>([
                .failure(NSError(domain: "", code: 0)),
                .success(())
            ]),
            retrier: mockRetrier,
            repeater: { _, _, _, _ in
                await repeaterInvocations.increment()
                return .doNotRetry
            }
        ).result

        let count = await repeaterInvocations.value
        XCTAssertEqual(count, 1,
            "The repeater should be invoked exactly once — after the retrier loop produces a terminal result.")
    }
    
    func testRepeaterStillRunsOnceWhenNoRetrierFires() async throws {
        let repeaterInvocations = Counter()

        _ = await Mock.Route(
            session: NetworkingSession(urlSession: Mock.UrlSession()),
            responseSerializer: Mock.ResponseSerializer<Void>(.success(())),
            repeater: { _, _, _, _ in
                await repeaterInvocations.increment()
                return .doNotRetry
            }
        ).result

        let count = await repeaterInvocations.value
        XCTAssertEqual(count, 1,
            "The repeater should still be invoked exactly once on a successful request with no retrier.")
    }
}
