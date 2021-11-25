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

        let mockAdapter = MockRequestInterceptor(adapterResult: .doNotAdapt,
                                                 retrierResult: .doNotRetry)
        let session = NetworkingSession(session: MockUrlSession(), requestAdapter: mockAdapter)
        let mockRoute = MockRoute<Void>()
        _ = await session.execute(route: mockRoute).result

        XCTAssertTrue(mockAdapter.adapterDidRun)
    }

    func testAdapterModifiesUrlRequest() async throws {

        let adaptedUrlRequest = URLRequest(url: URL(string: "https://adaptedRequest.com")!)
        let mockAdapter = MockRequestInterceptor(adapterResult: .adapted(mockAdaptedUrlRequest: adaptedUrlRequest),
                                                 retrierResult: .doNotRetry)
        let mockUrlSession = MockUrlSession()
        let session = NetworkingSession(session: mockUrlSession, requestAdapter: mockAdapter)
        let mockRoute = MockRoute<Void>(baseUrl: "https://originalRequest.com")
        _ = await session.execute(route: mockRoute).result

        XCTAssertTrue(mockAdapter.adapterDidRun)
        XCTAssertNotNil(mockUrlSession.lastRequest?.url)
        XCTAssertEqual(mockUrlSession.lastRequest?.url, adaptedUrlRequest.url)
    }

    func testAdapterThrowingFailsTheUrlRequest() async throws {

        let mockAdapterError = NSError(domain: "adapter failed", code: 0)
        let mockAdapter = MockRequestInterceptor(adapterResult: .failure(error: mockAdapterError),
                                                 retrierResult: .doNotRetry)
        let session = NetworkingSession(session: MockUrlSession(), requestAdapter: mockAdapter)
        let mockResponseSerializer = MockResponseSerializer<Void>(.success(()))
        let mockRoute = MockRoute(responseSerializer: mockResponseSerializer)
        _ = await session.execute(route: mockRoute).result

        XCTAssertTrue(mockAdapter.adapterDidRun)
        XCTAssertNotNil(mockResponseSerializer.payload?.responseError)
        XCTAssertEqual(mockResponseSerializer.payload?.responseError as NSError?, mockAdapterError)
    }
}
