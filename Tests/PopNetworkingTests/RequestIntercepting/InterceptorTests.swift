//
//  InterceptorTests.swift
//  
//
//  Created by Dan_Koza on 11/11/21.
//

import XCTest
@testable import PopNetworking

class InterceptorTests: XCTestCase {

    func testAllRequestInterceptorsRun() async throws {

        let mockRequestInterceptor1 = Mock.RequestInterceptor(adapterResult: .doNotAdapt,
                                                              retrierResult: .doNotRetry)
        let mockRequestInterceptor2 = Mock.RequestInterceptor(adapterResult: .doNotAdapt,
                                                              retrierResult: .doNotRetry)
        let session = NetworkingSession(session: Mock.UrlSession(),
                                        interceptor: Interceptor(requestInterceptors: [mockRequestInterceptor1, mockRequestInterceptor2]))
        _ = await session.execute(route: Mock.Route<Void>()).result

        XCTAssertTrue(mockRequestInterceptor1.adapterDidRun)
        XCTAssertTrue(mockRequestInterceptor1.retrierDidRun)
        XCTAssertTrue(mockRequestInterceptor2.adapterDidRun)
        XCTAssertTrue(mockRequestInterceptor2.retrierDidRun)
    }

    func testAdaptersDoNotRunAfterFirstFailure() async throws {

        let mockRequestInterceptor1 = Mock.RequestInterceptor(adapterResult: .failure(error: NSError(domain: "adapterFailure", code: 0)),
                                                              retrierResult: .doNotRetry)
        let mockRequestInterceptor2 = Mock.RequestInterceptor(adapterResult: .doNotAdapt,
                                                              retrierResult: .doNotRetry)
        let session = NetworkingSession(session: Mock.UrlSession(),
                                        interceptor: Interceptor(requestInterceptors: [mockRequestInterceptor1, mockRequestInterceptor2]))
        _ = await session.execute(route: Mock.Route<Void>()).result

        XCTAssertTrue(mockRequestInterceptor1.adapterDidRun)
        XCTAssertFalse(mockRequestInterceptor2.adapterDidRun)
    }

    func testStopRetryingAfterFirstSuccessfulRetry() async throws {

        let mockRequestInterceptor1 = Mock.RequestInterceptor(adapterResult: .doNotAdapt,
                                                              retrierResult: .retry)
        let mockRequestInterceptor2 = Mock.RequestInterceptor(adapterResult: .doNotAdapt,
                                                              retrierResult: .doNotRetry)
        let session = NetworkingSession(session: Mock.UrlSession(),
                                        interceptor: Interceptor(requestInterceptors: [mockRequestInterceptor1, mockRequestInterceptor2]))
        _ = await session.execute(route: Mock.Route(responseSerializer: Mock.ResponseSerializer([.failure(NSError()),
                                                                                                 .success(())]))).result
        XCTAssertTrue(mockRequestInterceptor1.retrierDidRun)
        XCTAssertFalse(mockRequestInterceptor2.retrierDidRun)
    }
}
