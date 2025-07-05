//
//  NetworkingSessionTests.swift
//  PopNetworking
//
//  Created by Dan Koza on 7/4/25.
//

import XCTest
@testable import PopNetworking

class NetworkingSessionTests: XCTestCase {

    func testMockResponse() async throws {
        let mockValue = try await Route(baseUrl: "www.mockedExample.com",
                                        responseSerializer: NetworkingResponseSerializers.HttpStatusCodeResponseSerializer(),
                                        mockSerializedResult: .success(123)).run

        XCTAssertEqual(mockValue, 123)
    }

    func testMockResponsesRunModifiers() async throws {
        let mockFailure = NSError(domain: "mock error", code: 0)
        let mockInterceptor = Mock.Interceptor(adapterResult: .doNotAdapt,
                                               retrierResult: .doNotRetry)
        let mockResult = await Route(baseUrl: "www.mockedExample.com",
                                     responseSerializer: NetworkingResponseSerializers.HttpStatusCodeResponseSerializer(),
                                     mockSerializedResult: .failure(mockFailure),
                                     interceptor: mockInterceptor).result

        XCTAssertThrowsError(try mockResult.get(), "we expect an invalid url error") { error in
            XCTAssertEqual(error as NSError, mockFailure)
        }
        let mockInterceptorAdapterDidRun = await mockInterceptor.adapterDidRun
        let mockInterceptorRetrierDidRun = await mockInterceptor.retrierDidRun
        XCTAssertTrue(mockInterceptorAdapterDidRun)
        XCTAssertTrue(mockInterceptorRetrierDidRun)
    }

    func testInvalidUrlRequestThrowsError() async throws {
        let result = await Route(baseUrl: "",
                                 responseSerializer: NetworkingResponseSerializers.HttpStatusCodeResponseSerializer()).result

        XCTAssertThrowsError(try result.get(), "we expect an invalid url error") { error in
            XCTAssertEqual((error as? URLError)?.code, .badURL)
        }
    }

    func testAdaptersPriority() async throws {

        let lowestPriorityAdapterError = NSError(domain: "lowest priority adapter failed", code: 0)
        let lowestPriorityAdapter = Mock.Interceptor(adapterResult: .failure(error: lowestPriorityAdapterError),
                                                     priority: .lowest)
        let highestPriorityAdapterError = NSError(domain: "highest priority adapter failed", code: 0)
        let highestPriorityAdapter = Mock.Interceptor(adapterResult: .failure(error: highestPriorityAdapterError),
                                                      priority: .highest)
        let result = await Mock.Route(session: NetworkingSession(urlSession: Mock.UrlSession(),
                                                                 adapter: lowestPriorityAdapter),
                                      responseSerializer: Mock.ResponseSerializer<Void>(),
                                      adapter: highestPriorityAdapter).result

        XCTAssertThrowsError(try result.get()) { error in
            XCTAssertEqual(error as NSError, highestPriorityAdapterError)
        }
    }

    func testRetriersPriority() async throws {

        let lowestPriorityRetrier = Mock.Interceptor(retrierResult: .doNotRetry,
                                                     priority: .lowest)
        let highestPriorityRetrier = Mock.Interceptor(retrierResult: .doNotRetry,
                                                      priority: .highest)
        _ = await Mock.Route(session: NetworkingSession(urlSession: Mock.UrlSession(),
                                                        retrier: lowestPriorityRetrier),
                             responseSerializer: Mock.ResponseSerializer<Void>(.failure(NSError(domain: "mock error", code: 0))),
                             retrier: highestPriorityRetrier).result

        let now = Date.now
        let highestPriorityRetrierRanDate = await highestPriorityRetrier.retrierRunDate ?? now
        let lowestPriorityRetrierRanDate = await lowestPriorityRetrier.retrierRunDate ?? now
        XCTAssertTrue(highestPriorityRetrierRanDate < lowestPriorityRetrierRanDate)
    }

    func testInterceptorsPriority() async throws {
        let mockInterceptorLowPriority = Mock.Interceptor(adapterResult: .doNotAdapt,
                                                          retrierResult: .doNotRetry,
                                                          priority: .low)
        let mockInterceptorHighPriority = Mock.Interceptor(adapterResult: .doNotAdapt,
                                                           retrierResult: .doNotRetry,
                                                           priority: .high)
        _ = await Mock.Route(session: NetworkingSession(urlSession: Mock.UrlSession(),
                                                        adapter: mockInterceptorLowPriority,
                                                        retrier: mockInterceptorLowPriority),
                             responseSerializer: Mock.ResponseSerializers<Void>([.failure(NSError(domain: "", code: 0))]),
                             interceptor: mockInterceptorHighPriority).result

        let now = Date.now
        let mockInterceptorLowPriorityAdapterRanDate = await mockInterceptorLowPriority.adapterRunDate ?? now
        let mockInterceptorHighPriorityAdapterRanDate = await mockInterceptorHighPriority.adapterRunDate ?? now
        let mockInterceptorHighPriorityRetrierRanDate = await mockInterceptorHighPriority.retrierRunDate ?? now
        let mockInterceptorLowPriorityRetrierRanDate = await mockInterceptorLowPriority.retrierRunDate ?? now
        XCTAssertTrue(mockInterceptorHighPriorityAdapterRanDate < mockInterceptorLowPriorityAdapterRanDate)
        XCTAssertTrue(mockInterceptorHighPriorityRetrierRanDate < mockInterceptorLowPriorityRetrierRanDate)
    }

    func testModifiersWithEqualPriority() async throws {
        let mockSessionAdapter = Mock.Interceptor(adapterResult: .doNotAdapt, priority: .standard)
        let mockSessionRetrier = Mock.Interceptor(retrierResult: .doNotRetry, priority: .standard)
        let mockRouteAdapter = Mock.Interceptor(adapterResult: .doNotAdapt, priority: .standard)
        let mockRouteRetrier = Mock.Interceptor(retrierResult: .doNotRetry, priority: .standard)
        let mockRouteInterceptor = Mock.Interceptor(adapterResult: .doNotAdapt, retrierResult: .doNotRetry, priority: .standard)
        _ = await Mock.Route(session: NetworkingSession(urlSession: Mock.UrlSession(),
                                                        adapter: mockSessionAdapter,
                                                        retrier: mockSessionRetrier),
                             responseSerializer: Mock.ResponseSerializers<Void>([.failure(NSError(domain: "", code: 0))]),
                             adapter: mockRouteAdapter,
                             retrier: mockRouteRetrier,
                             interceptor: mockRouteInterceptor).result

        let now = Date.now
        let mockSessionAdapterRanDate = await mockSessionAdapter.adapterRunDate ?? now
        let mockSessionRetrierRanDate = await mockSessionRetrier.retrierRunDate ?? now
        let mockRouteAdapterRanDate = await mockRouteAdapter.adapterRunDate ?? now
        let mockRouteRetrierRanDate = await mockRouteRetrier.retrierRunDate ?? now
        let mockRouteInterceptorAdapterRanDate = await mockRouteInterceptor.adapterRunDate ?? now
        let mockRouteInterceptorRetrierRanDate = await mockRouteInterceptor.retrierRunDate ?? now
        XCTAssertTrue(mockSessionAdapterRanDate < mockRouteAdapterRanDate)
        XCTAssertTrue(mockRouteAdapterRanDate < mockRouteInterceptorAdapterRanDate)
        XCTAssertTrue(mockSessionRetrierRanDate < mockRouteRetrierRanDate)
        XCTAssertTrue(mockRouteRetrierRanDate < mockRouteInterceptorRetrierRanDate)
    }

}
