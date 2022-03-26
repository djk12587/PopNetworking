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
        let result = await Mock.Route(responseSerializer: .mock(.success("mock_success_response"))).result

        XCTAssertNoThrow(try result.get())
    }

    func testResponseSerializerSerializesFailureResponse() async throws {
        let mockError = NSError(domain: "failed to serialize", code: 0)
        let result = await Mock.Route(responseSerializer: .mock(Result<Void, Error>.failure(mockError))).result

        XCTAssertThrowsError(try result.get()) { error in
            XCTAssertEqual(error as NSError, mockError)
        }
    }
}
