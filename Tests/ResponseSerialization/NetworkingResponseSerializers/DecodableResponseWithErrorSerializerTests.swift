//
//  DecodableResponseAndErrorSerializer.swift
//
//
//  Created by Dan_Koza on 12/2/21.
//

import XCTest
@testable import PopNetworking

class DecodableResponseAndErrorSerializerTests: XCTestCase {

    func testSuccess() async throws {

        let mockModel = Mock.DecodableModel(mockProperty: "mock value")
        let encodedModel = try JSONEncoder().encode(mockModel)
        let responseModel = try await Mock.Route(session: NetworkingSession(urlSession: Mock.UrlSession(mockResult: .success(encodedModel))),
                                                 responseSerializer: NetworkingResponseSerializers.DecodableResponseAndErrorSerializer<Mock.DecodableModel, Mock.DecodableError>()).task().result.get()
        XCTAssertNotEqual(mockModel, responseModel)
    }

    func testDecodingFailure() async throws {

        let mockErrorModel = Mock.DecodableError(mockErrorCode: 123)
        let encoder = JSONEncoder()
        let encodedMockErrorModel = try encoder.encode(mockErrorModel)
        let responseResult = await Mock.Route(session: NetworkingSession(urlSession: Mock.UrlSession(mockResult: .success(encodedMockErrorModel))),
                                              responseSerializer: NetworkingResponseSerializers.DecodableResponseAndErrorSerializer<Mock.DecodableModel, Mock.DecodableError>()).task().result
        XCTAssertThrowsError(try responseResult.get()) { error in
            XCTAssertNotNil(error as? Mock.DecodableError)
            XCTAssertEqual(error as? Mock.DecodableError, mockErrorModel)
        }
    }

    func testSuccessAndErrorDecodingFailures() async throws {

        let unexpectedErrorData = try JSONEncoder().encode(["mockErrorMessage" : "some reason why an error occured"])
        let responseResult = await Mock.Route(session: NetworkingSession(urlSession: Mock.UrlSession(mockResult: .success(unexpectedErrorData))),
                                              responseSerializer: NetworkingResponseSerializers.DecodableResponseAndErrorSerializer<Mock.DecodableModel, Mock.DecodableError>()).task().result
        XCTAssertThrowsError(try responseResult.get()) { error in

            guard let errors = error as? [DecodingError] else {
                XCTFail("error should be of type [DecodingError]")
                return
            }
            XCTAssertEqual(errors.count, 2)
        }
    }

    func testNetworkingFailure() async throws {

        let mockNetworkingResponseError = NSError(domain: "mock error", code: 1)
        let responseResult = await Mock.Route(session: NetworkingSession(urlSession: Mock.UrlSession(mockResult: .failure(mockNetworkingResponseError))),
                                              responseSerializer: NetworkingResponseSerializers.DecodableResponseAndErrorSerializer<Mock.DecodableModel, Mock.DecodableError>()).task().result
        XCTAssertThrowsError(try responseResult.get()) { error in
            XCTAssertEqual(mockNetworkingResponseError, error as NSError)
        }
    }
}

private extension Mock {
    struct DecodableModel: Codable, Equatable {
        let mockProperty: String
    }

    struct DecodableError: Codable, Equatable, Error {
        let mockErrorCode: Int
    }

    struct UnexpectedError: Codable, Equatable, Error {
        let mockErrorMessage: String
    }
}
