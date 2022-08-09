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
        let routeTask = Route(baseUrl: "www.thisRequestWillBeCancelled.com",
                              responseSerializer: NetworkingResponseSerializers.DataResponseSerializer()).task()
        routeTask.cancel()
        do {
            _ = try await routeTask.value
            XCTFail("routeTask.value should throw a cancellation error")
        } catch {
            XCTAssertEqual((error as NSError).code, URLError.cancelled.rawValue)
            XCTAssertNotNil((error as NSError).userInfo["Reason"])
        }
    }
}
