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
        let serializedValue = try await Mock.Route(responseSerializer: Mock.ResponseSerializer(.success("mock_success_response"))).run

        XCTAssertEqual(serializedValue, "mock_success_response")
    }

    func testResponseSerializerSerializesFailureResponse() async throws {
        let mockError = NSError(domain: "failed to serialize", code: 0)
        let result = await Mock.Route(responseSerializer: Mock.ResponseSerializer<Void>(.failure(mockError))).result

        XCTAssertThrowsError(try result.get()) { error in
            XCTAssertEqual(error as NSError, mockError)
        }
    }
}
