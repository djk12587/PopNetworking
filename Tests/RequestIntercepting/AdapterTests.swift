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
        _ = await Mock.Route(session: NetworkingSession(urlSession: Mock.UrlSession(), requestAdapter: mockAdapter),
                             responseSerializer: .mock(.success(Void()))).result

        XCTAssertTrue(mockAdapter.adapterDidRun)
    }

    func testAdapterModifiesUrlRequest() async throws {

        let adaptedUrlRequest = URLRequest(url: URL(string: "https://adaptedRequest.com")!)
        let mockAdapter = Mock.RequestInterceptor(adapterResult: .adapt(adaptedUrlRequest: adaptedUrlRequest),
                                                  retrierResult: .doNotRetry)
        let mockUrlSession = Mock.UrlSession()
        _ = await Mock.Route(baseUrl: "https://originalRequest.com",
                             session: NetworkingSession(urlSession: mockUrlSession, requestAdapter: mockAdapter),
                             responseSerializer: .mock(.success(Void()))).result

        XCTAssertTrue(mockAdapter.adapterDidRun)
        XCTAssertNotNil(mockUrlSession.lastRequest?.url)
        XCTAssertEqual(mockUrlSession.lastRequest?.url, adaptedUrlRequest.url)
    }

    func testAdapterThrowingFailsTheUrlRequest() async throws {

        let mockAdapterError = NSError(domain: "adapter failed", code: 0)
        let mockAdapter = Mock.RequestInterceptor(adapterResult: .failure(error: mockAdapterError),
                                                  retrierResult: .doNotRetry)
        let result = await Mock.Route(session: NetworkingSession(urlSession: Mock.UrlSession(), requestAdapter: mockAdapter),
                                      responseSerializer: .mock(.success(Void()))).result
        XCTAssertThrowsError(try result.get()) { error in
            XCTAssertEqual(error as NSError, mockAdapterError)
        }
        XCTAssertTrue(mockAdapter.adapterDidRun)
    }
}
