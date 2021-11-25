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

        let mockRetrier = MockRequestInterceptor(adapterResult: .doNotAdapt,
                                                 retrierResult: .doNotRetry)
        let session = NetworkingSession(session: MockUrlSession(), requestRetrier: mockRetrier)
        let mockRoute = MockRoute<Void>(responseSerializer: MockResponseSerializer(.success(())))
        _ = await session.execute(route: mockRoute).result

        XCTAssertFalse(mockRetrier.retrierDidRun)
    }

    func testRetrierRunsWhenRequestFails() async throws {

        let mockRetrier = MockRequestInterceptor(adapterResult: .doNotAdapt,
                                                 retrierResult: .doNotRetry)
        let session = NetworkingSession(session: MockUrlSession(), requestRetrier: mockRetrier)
        let mockRoute = MockRoute<Void>(responseSerializer: MockResponseSerializer(.failure(NSError())))
        let result = await session.execute(route: mockRoute).result

        XCTAssertTrue(mockRetrier.retrierDidRun)
        XCTAssertThrowsError(try result.get())
    }

    func testRetrierRunsMultipleTimesWhenRequestFailsAgain() async throws {

        let mockRetrier = MockRequestInterceptor(adapterResult: .doNotAdapt,
                                                 retrierResult: .retry)
        let session = NetworkingSession(session: MockUrlSession(), requestRetrier: mockRetrier)
        let mockRoute = MockRoute<Void>(responseSerializer: MockResponseSerializer([.failure(NSError()), .success(())]))
        let result = await session.execute(route: mockRoute).result

        XCTAssertTrue(mockRetrier.retrierDidRun)
        XCTAssertEqual(mockRetrier.retryCounter, 1)
        XCTAssertNoThrow(try result.get())
    }
}
