//
//  File.swift
//  
//
//  Created by Dan_Koza on 11/17/21.
//

import XCTest
@testable import PopNetworking

class AdapterTests: XCTestCase {

    func testAdapterRuns() async throws {

        let mockAdapter = Mock.RequestInterceptor(adapterResult: .doNotAdapt,
                                                  retrierResult: .doNotRetry)
        let session = NetworkingSession(session: Mock.UrlSession(), requestAdapter: mockAdapter)
        let mockRoute = Mock.Route<Void>()
        _ = await session.execute(route: mockRoute).result

        XCTAssertTrue(mockAdapter.adapterDidRun)
    }

    func testAdapterModifiesUrlRequest() async throws {

        let adaptedUrlRequest = URLRequest(url: URL(string: "https://adaptedRequest.com")!)
        let mockAdapter = Mock.RequestInterceptor(adapterResult: .adapt(adaptedUrlRequest: adaptedUrlRequest),
                                                  retrierResult: .doNotRetry)
        let mockUrlSession = Mock.UrlSession()
        let session = NetworkingSession(session: mockUrlSession, requestAdapter: mockAdapter)
        let mockRoute = Mock.Route<Void>(baseUrl: "https://originalRequest.com")
        _ = await session.execute(route: mockRoute).result

        XCTAssertTrue(mockAdapter.adapterDidRun)
        XCTAssertNotNil(mockUrlSession.lastRequest?.url)
        XCTAssertEqual(mockUrlSession.lastRequest?.url, adaptedUrlRequest.url)
    }

    func testAdapterThrowingFailsTheUrlRequest() async throws {

        let mockAdapterError = NSError(domain: "adapter failed", code: 0)
        let mockAdapter = Mock.RequestInterceptor(adapterResult: .failure(error: mockAdapterError),
                                                  retrierResult: .doNotRetry)
        let session = NetworkingSession(session: Mock.UrlSession(), requestAdapter: mockAdapter)
        let mockResponseSerializer = Mock.ResponseSerializer<Void>(.success(()))
        let mockRoute = Mock.Route(responseSerializer: mockResponseSerializer)
        _ = await session.execute(route: mockRoute).result

        XCTAssertTrue(mockAdapter.adapterDidRun)
        XCTAssertNotNil(mockResponseSerializer.payload?.responseError)
        XCTAssertEqual(mockResponseSerializer.payload?.responseError as NSError?, mockAdapterError)
    }
}
