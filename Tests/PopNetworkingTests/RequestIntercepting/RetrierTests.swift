//
//  File.swift
//  
//
//  Created by Dan_Koza on 11/17/21.
//

import XCTest
@testable import PopNetworking

class RetrierTests: XCTestCase {

    func testRetrierDoesNotRunWhenRequestSucceeds() async throws {

        let mockRetrier = Mock.RequestInterceptor(adapterResult: .doNotAdapt,
                                                  retrierResult: .doNotRetry)
        _ = await Mock.Route(session: NetworkingSession(urlSession: Mock.UrlSession(), requestRetrier: mockRetrier),
                             responseSerializer: Mock.ResponseSerializer<Void>(.success(()))).asyncResult

        XCTAssertFalse(mockRetrier.retrierDidRun)
    }

    func testRetrierRunsWhenRequestFails() async throws {

        let mockRetrier = Mock.RequestInterceptor(adapterResult: .doNotAdapt,
                                                  retrierResult: .doNotRetry)
        let result = await Mock.Route(session: NetworkingSession(urlSession: Mock.UrlSession(), requestRetrier: mockRetrier),
                                      responseSerializer: Mock.ResponseSerializer<Void>(.failure(NSError()))).asyncResult

        XCTAssertTrue(mockRetrier.retrierDidRun)
        XCTAssertThrowsError(try result.get())
    }

    func testRetrierRunsMultipleTimesWhenRequestFailsAgain() async throws {

        let mockRetrier = Mock.RequestInterceptor(adapterResult: .doNotAdapt,
                                                  retrierResult: .retry)
        let result = await Mock.Route(session: NetworkingSession(urlSession: Mock.UrlSession(), requestRetrier: mockRetrier),
                                      responseSerializer: Mock.ResponseSerializer<Void>([.failure(NSError()), .success(())])).asyncResult

        XCTAssertTrue(mockRetrier.retrierDidRun)
        XCTAssertEqual(mockRetrier.retryCounter, 1)
        XCTAssertNoThrow(try result.get())
    }
}
