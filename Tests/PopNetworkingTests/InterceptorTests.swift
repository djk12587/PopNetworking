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

        let mockRequestInterceptor1 = MockRequestInterceptor()
        mockRequestInterceptor1.adapterFailure = nil
        mockRequestInterceptor1.retrierResult = .doNotRetry

        let mockRequestInterceptor2 = MockRequestInterceptor()
        mockRequestInterceptor2.adapterFailure = nil
        mockRequestInterceptor2.retrierResult = .doNotRetry

        let session = NetworkingSession(session: MockUrlSession(),
                                        interceptor: Interceptor(requestInterceptors: [mockRequestInterceptor1, mockRequestInterceptor2]))
        _ = await session.execute(route: MockRoute()).result

        XCTAssertTrue(mockRequestInterceptor1.adapterDidRun)
        XCTAssertTrue(mockRequestInterceptor1.retrierDidRun)
        XCTAssertTrue(mockRequestInterceptor2.adapterDidRun)
        XCTAssertTrue(mockRequestInterceptor2.retrierDidRun)
    }

    func testAdaptersDoNotRunAfterFirstFailure() async throws {

        let mockRequestInterceptor1 = MockRequestInterceptor()
        mockRequestInterceptor1.adapterFailure = .adapterFailure
        mockRequestInterceptor1.retrierResult = .doNotRetry

        let mockRequestInterceptor2 = MockRequestInterceptor()
        mockRequestInterceptor2.adapterFailure = nil
        mockRequestInterceptor2.retrierResult = .doNotRetry

        let session = NetworkingSession(session: MockUrlSession(),
                                        interceptor: Interceptor(requestInterceptors: [mockRequestInterceptor1, mockRequestInterceptor2]))
        _ = await session.execute(route: MockRoute()).result

        XCTAssertTrue(mockRequestInterceptor1.adapterDidRun)
        XCTAssertFalse(mockRequestInterceptor2.adapterDidRun)
    }

    func testStopRetryingAfterFirstSuccessfulRetry() async throws {

        let mockRequestInterceptor1 = MockRequestInterceptor()
        mockRequestInterceptor1.adapterFailure = nil
        mockRequestInterceptor1.retrierResult = .retry

        let mockRequestInterceptor2 = MockRequestInterceptor()
        mockRequestInterceptor2.adapterFailure = nil
        mockRequestInterceptor2.retrierResult = .doNotRetry

        let mockedInitialResult: Result<Void, Error> = .failure(NSError())
        let mockedRetryResult: Result<Void, Error> = .success(())
        let session = NetworkingSession(session: MockUrlSession(),
                                        interceptor: Interceptor(requestInterceptors: [mockRequestInterceptor1, mockRequestInterceptor2]))
        _ = await session.execute(route: MockRoute(responseSerializer: MockResponseSerializer([mockedInitialResult,
                                                                                               mockedRetryResult]))).result
        XCTAssertTrue(mockRequestInterceptor1.retrierDidRun)
        XCTAssertFalse(mockRequestInterceptor2.retrierDidRun)
    }
}

private extension InterceptorTests {

    class MockRequestInterceptor: NetworkingRequestInterceptor {

        enum MockRequestInterceptorError: Error {
            case adapterFailure
        }

        var adapterDidRun = false
        var adapterFailure: MockRequestInterceptorError?
        func adapt(urlRequest: URLRequest) async throws -> URLRequest {
            defer { adapterDidRun = true }
            guard let adapterFailure = adapterFailure else { return urlRequest }
            throw adapterFailure
        }

        var retrierDidRun = false
        var retrierResult: NetworkingRequestRetrierResult = .doNotRetry
        func retry(urlRequest: URLRequest?, dueTo error: Error, urlResponse: HTTPURLResponse?, retryCount: Int) async -> NetworkingRequestRetrierResult {
            defer { retrierDidRun = true }
            return retrierResult
        }
    }
}
