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
        let interceptor = Interceptor(adapters: [mockRequestInterceptor1, mockRequestInterceptor2],
                                      retriers: [mockRequestInterceptor1, mockRequestInterceptor2])
        _ = await Mock.Route(session: NetworkingSession(urlSession: Mock.UrlSession(),
                                                        requestAdapter: interceptor,
                                                        requestRetrier: interceptor),
                             responseSerializer: Mock.ResponseSerializers<Void>([.failure(NSError(domain: "error", code: 1))])).result

        let interceptor1AdapterDidRun = await mockRequestInterceptor1.adapterDidRun
        let interceptor1RetrierDidRun = await mockRequestInterceptor1.retrierDidRun
        let interceptor2AdapterDidRun = await mockRequestInterceptor2.adapterDidRun
        let interceptor2RetrierDidRun = await mockRequestInterceptor2.retrierDidRun
        XCTAssertTrue(interceptor1AdapterDidRun)
        XCTAssertTrue(interceptor1RetrierDidRun)
        XCTAssertTrue(interceptor2AdapterDidRun)
        XCTAssertTrue(interceptor2RetrierDidRun)
    }

    func testAdaptersDoNotRunAfterFirstFailure() async throws {

        let mockRequestInterceptor1 = Mock.RequestInterceptor(adapterResult: .failure(error: NSError(domain: "adapterFailure", code: 0)),
                                                              retrierResult: .doNotRetry)
        let mockRequestInterceptor2 = Mock.RequestInterceptor(adapterResult: .doNotAdapt,
                                                              retrierResult: .doNotRetry)
        let interceptor = Interceptor(requestInterceptors: [mockRequestInterceptor1, mockRequestInterceptor2])
        _ = await Mock.Route(session: NetworkingSession(urlSession: Mock.UrlSession(),
                                                        requestAdapter: interceptor,
                                                        requestRetrier: interceptor),
                             responseSerializer: Mock.ResponseSerializer<Void>()).result

        let interceptor1AdapterDidRun = await mockRequestInterceptor1.adapterDidRun
        let interceptor2AdapterDidRun = await mockRequestInterceptor2.adapterDidRun
        XCTAssertTrue(interceptor1AdapterDidRun)
        XCTAssertFalse(interceptor2AdapterDidRun)
    }

    func testStopRetryingAfterFirstSuccessfulRetry() async throws {

        let mockRequestInterceptor1 = Mock.RequestInterceptor(adapterResult: .doNotAdapt,
                                                              retrierResult: .retry)
        let mockRequestInterceptor2 = Mock.RequestInterceptor(adapterResult: .doNotAdapt,
                                                              retrierResult: .doNotRetry)
        let interceptor = Interceptor(requestInterceptors: [mockRequestInterceptor1, mockRequestInterceptor2])
        _ = await Mock.Route(session: NetworkingSession(urlSession: Mock.UrlSession(),
                                                        requestAdapter: interceptor,
                                                        requestRetrier: interceptor),
                             responseSerializer: Mock.ResponseSerializers([.failure(NSError(domain: "", code: 0)), .success(())])).result

        let interceptor1RetrierDidRun = await mockRequestInterceptor1.retrierDidRun
        let interceptor2RetrierDidRun = await mockRequestInterceptor2.retrierDidRun
        XCTAssertTrue(interceptor1RetrierDidRun)
        XCTAssertFalse(interceptor2RetrierDidRun)
    }

    func testStopRetryingAfterFirstSuccessfulRetryWithDelay() async throws {

        let mockRequestInterceptor1 = Mock.RequestInterceptor(adapterResult: .doNotAdapt,
                                                              retrierResult: .retryWithDelay(0))
        let mockRequestInterceptor2 = Mock.RequestInterceptor(adapterResult: .doNotAdapt,
                                                              retrierResult: .doNotRetry)
        let interceptor = Interceptor(requestInterceptors: [mockRequestInterceptor1, mockRequestInterceptor2])
        _ = await Mock.Route(session: NetworkingSession(urlSession: Mock.UrlSession(),
                                                        requestAdapter: interceptor,
                                                        requestRetrier: interceptor),
                             responseSerializer: Mock.ResponseSerializers([.failure(NSError(domain: "", code: 0)), .success(())])).result

        let interceptor1RetrierDidRun = await mockRequestInterceptor1.retrierDidRun
        let interceptor2RetrierDidRun = await mockRequestInterceptor2.retrierDidRun
        XCTAssertTrue(interceptor1RetrierDidRun)
        XCTAssertFalse(interceptor2RetrierDidRun)
    }
}
