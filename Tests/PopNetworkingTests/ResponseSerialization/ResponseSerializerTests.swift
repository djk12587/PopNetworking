//
//  File.swift
//  
//
//  Created by Dan_Koza on 11/17/21.
//

import Foundation

import XCTest
@testable import PopNetworking

class ResponseSerializerTests: XCTestCase {

    func testResponseSerializerSerializesSuccessResponse() async throws {
        let mockRoute = MockRoute<Int>(responseSerializer: MockResponseSerializer(.success(24)))
        let session = NetworkingSession(session: MockUrlSession())
        let result = await session.execute(route: mockRoute).result
        XCTAssertEqual(try result.get(), 24)
    }

    func testResponseSerializerSerializesFailureResponse() async throws {
        let mockError = NSError(domain: "failed to serialize", code: 0)
        let mockRoute = MockRoute<Int>(responseSerializer: MockResponseSerializer(.failure(mockError)))
        let session = NetworkingSession(session: MockUrlSession())
        let result = await session.execute(route: mockRoute).result

        do {
            _ = try result.get()
            XCTFail("this request should fail")
        } catch {
            XCTAssertEqual(error as NSError, mockError)
        }
    }
}
