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
        let session = NetworkingSession(session: Mock.UrlSession(), requestRetrier: mockRetrier)
        let mockRoute = Mock.Route<Void>(responseSerializer: Mock.ResponseSerializer(.success(())))
        _ = await session.execute(route: mockRoute).result

        XCTAssertFalse(mockRetrier.retrierDidRun)
    }

    func testRetrierRunsWhenRequestFails() async throws {

        let mockRetrier = Mock.RequestInterceptor(adapterResult: .doNotAdapt,
                                                  retrierResult: .doNotRetry)
        let session = NetworkingSession(session: Mock.UrlSession(), requestRetrier: mockRetrier)
        let mockRoute = Mock.Route<Void>(responseSerializer: Mock.ResponseSerializer(.failure(NSError())))
        let result = await session.execute(route: mockRoute).result

        XCTAssertTrue(mockRetrier.retrierDidRun)
        XCTAssertThrowsError(try result.get())
    }

    func testRetrierRunsMultipleTimesWhenRequestFailsAgain() async throws {

        let mockRetrier = Mock.RequestInterceptor(adapterResult: .doNotAdapt,
                                                  retrierResult: .retry)
        let session = NetworkingSession(session: Mock.UrlSession(), requestRetrier: mockRetrier)
        let mockRoute = Mock.Route<Void>(responseSerializer: Mock.ResponseSerializer([.failure(NSError()), .success(())]))
        let result = await session.execute(route: mockRoute).result

        XCTAssertTrue(mockRetrier.retrierDidRun)
        XCTAssertEqual(mockRetrier.retryCounter, 1)
        XCTAssertNoThrow(try result.get())
    }
}
