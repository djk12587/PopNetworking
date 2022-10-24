//
//  ResponseValidatorTests.swift
//  
//
//  Created by Dan Koza on 10/24/22.
//

import XCTest
@testable import PopNetworking

class ResponseValidatorTests: XCTestCase {

    func testResponseValidatorFailsRequest() async throws {
        let mockError = NSError(domain: "failed validation", code: 0)
        let result = await Mock.Route(responseValidator: Mock.ResponseValidator(mockValidationError: mockError),
                                      responseSerializer: Mock.ResponseSerializer(.success("mock_success_response"))).result

        XCTAssertThrowsError(try result.get()) { error in
            XCTAssertEqual(error as NSError, mockError)
        }
    }

    func testResponseValidatorValidatesRequest() async throws {
        let result = await Mock.Route(responseValidator: Mock.ResponseValidator(mockValidationError: nil),
                                      responseSerializer: Mock.ResponseSerializer<Void>(.success(Void()))).result
        XCTAssertNoThrow(try result.get())
    }
}
