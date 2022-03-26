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
                             responseSerializer: .mock(.success(Void()))).result

        XCTAssertFalse(mockRetrier.retrierDidRun)
    }

    func testRetrierRunsWhenRequestFails() async throws {

        let mockRetrier = Mock.RequestInterceptor(adapterResult: .doNotAdapt,
                                                  retrierResult: .doNotRetry)
        let result = await Mock.Route(session: NetworkingSession(urlSession: Mock.UrlSession(), requestRetrier: mockRetrier),
                                      responseSerializer: .mock(Result<Void, Error>.failure(NSError()))).result

        XCTAssertTrue(mockRetrier.retrierDidRun)
        XCTAssertThrowsError(try result.get())
    }

    func testRetrierRunsMultipleTimesWhenRequestFailsAgain() async throws {

        let mockRetrier = Mock.RequestInterceptor(adapterResult: .doNotAdapt,
                                                  retrierResult: .retryWithDelay(0))
        let result = await Mock.Route(session: NetworkingSession(urlSession: Mock.UrlSession(), requestRetrier: mockRetrier),
                                      responseSerializer: .mock([.failure(NSError()), .success(Void())])).result

        XCTAssertTrue(mockRetrier.retrierDidRun)
        XCTAssertEqual(mockRetrier.retryCounter, 1)
        XCTAssertNoThrow(try result.get())
    }
}
