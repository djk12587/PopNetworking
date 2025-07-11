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

        let mockRetrier = Mock.Interceptor(adapterResult: .doNotAdapt,
                                           retrierResult: .doNotRetry)
        _ = await Mock.Route(session: NetworkingSession(urlSession: Mock.UrlSession(), retrier: mockRetrier),
                             responseSerializer: Mock.ResponseSerializer<Void>()).result

        let retrierDidRun = await mockRetrier.retrierDidRun
        XCTAssertFalse(retrierDidRun)
    }

    func testRetrierRunsWhenRequestFails() async throws {

        let mockRetrier = Mock.Interceptor(adapterResult: .doNotAdapt,
                                           retrierResult: .doNotRetry)
        let result = await Mock.Route(session: NetworkingSession(urlSession: Mock.UrlSession(), retrier: mockRetrier),
                                      responseSerializer: Mock.ResponseSerializer<Void>(.failure(NSError(domain: "", code: 0)))).result

        let retrierDidRun = await mockRetrier.retrierDidRun
        XCTAssertTrue(retrierDidRun)
        XCTAssertThrowsError(try result.get())
    }

    func testRetrierRunsMultipleTimesWhenRequestFailsAgain() async throws {

        let mockRetrier = Mock.Interceptor(adapterResult: .doNotAdapt,
                                           retrierResult: .retryWithDelay(0))
        let result = await Mock.Route(session: NetworkingSession(urlSession: Mock.UrlSession(), retrier: mockRetrier),
                                      responseSerializer: Mock.ResponseSerializers<Void>([.failure(NSError(domain: "", code: 0)), .success(())])).result

        let retrierDidRun = await mockRetrier.retrierDidRun
        let retrierCount = await mockRetrier.retryCounter
        XCTAssertTrue(retrierDidRun)
        XCTAssertEqual(retrierCount, 1)
        XCTAssertNoThrow(try result.get())
    }
}
