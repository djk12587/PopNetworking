//
//  NetworkingRouteTests.swift
//  
//
//  Created by Dan_Koza on 2/16/22.
//

import XCTest
@testable import PopNetworking

class NetworkingRouteTests: XCTestCase {

    func testCancellingNetworkingRoute() {
        let expectation = expectation(description: "this")
        let routeTask = Route(baseUrl: "www.thisRequestWillBeCancelled.com", responseSerializer: NetworkingResponseSerializers.DataResponseSerializer()).request { result in
            do {
                _ = try result.get()
                XCTFail("result.get() should throw a cancellation error")
            } catch {
                XCTAssertEqual((error as NSError).code, NSURLErrorCancelled)
            }
            expectation.fulfill()
        }
        routeTask.cancel()
        waitForExpectations(timeout: 10)
    }
}
