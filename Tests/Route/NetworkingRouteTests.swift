//
//  NetworkingRouteTests.swift
//  
//
//  Created by Dan_Koza on 2/16/22.
//

import XCTest
@testable import PopNetworking

class NetworkingRouteTests: XCTestCase {

    func testCancellingNetworkingRouteRequest() {
        let expectation = expectation(description: "this")
        let routeTask = Route(baseUrl: "www.thisRequestWillBeCancelled.com",
                              responseSerializer: NetworkingResponseSerializers.DataResponseSerializer()).request { result in
            do {
                _ = try result.get()
                XCTFail("result.get() should throw a cancellation error")
            } catch {
                XCTAssertEqual((error as NSError).code, URLError.cancelled.rawValue)
                XCTAssertNotNil((error as NSError).userInfo["Reason"])
                XCTAssertNotNil((error as NSError).userInfo["RawPayload"])
            }
            expectation.fulfill()
        }
        routeTask.cancel()
        waitForExpectations(timeout: 10)
    }

    func testCancellingNetworkingRouteTask() async throws {
        let routeTask = Route(baseUrl: "www.thisRequestWillBeCancelled.com",
                              responseSerializer: NetworkingResponseSerializers.DataResponseSerializer()).task()
        routeTask.cancel()
        do {
            _ = try await routeTask.value
            XCTFail("routeTask.value should throw a cancellation error")
        } catch {
            XCTAssertEqual((error as NSError).code, URLError.cancelled.rawValue)
            XCTAssertNotNil((error as NSError).userInfo["Reason"])
            XCTAssertNotNil((error as NSError).userInfo["RawPayload"])
        }
    }

    func testRequestDoesNotTimeout() async throws {
        let routeTask = Mock.Route(baseUrl: "www.mockUrl.com",
                                   responseSerializer: Mock.ResponseSerializer(.success("success")),
                                   timeout: 1).task()
        do {
            let success = try await routeTask.value
            XCTAssertEqual(success, "success")
        } catch {
            print(error)
            XCTFail("the request should not timeout")
        }
    }

    func testRequestTimesout() async throws {

        let routeTask = Mock.Route(baseUrl: "www.mockUrl.com",
                                   session: NetworkingSession(urlSession: Mock.UrlSession(mockDelay: 1)),
                                   responseSerializer: Mock.ResponseSerializer(.success("success")),
                                   timeout: 0).task()
        do {
            let success = try await routeTask.value
            XCTAssertEqual(success, "this request should have timed out")
        } catch {
            XCTAssertEqual((error as NSError).code, URLError.timedOut.rawValue)
            XCTAssertNotNil((error as NSError).userInfo["Reason"])
        }
    }
}
