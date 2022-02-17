//
//  DecodableResponseWithErrorSerializerTests.swift
//  
//
//  Created by Dan_Koza on 12/2/21.
//

import XCTest
@testable import PopNetworking

class DecodableResponseWithErrorSerializerTests: XCTestCase {

    func testSuccess() async throws {

        let mockModel = Mock.DecodableModel(mockProperty: "mock value")
        let encodedModel = try JSONEncoder().encode(mockModel)
        let responseModel = try await Mock.Route(session: NetworkingSession(urlSession: Mock.UrlSession(mockResponseData: encodedModel)),
                                                 responseSerializer: NetworkingResponseSerializers.DecodableResponseWithErrorSerializer<Mock.DecodableModel, Mock.DecodableError>()).task().result.get()
        XCTAssertEqual(mockModel, responseModel)
    }

    func testDecodingFailure() async throws {

        let mockErrorModel = Mock.DecodableError(mockErrorCode: 123)
        let encoder = JSONEncoder()
        let encodedMockErrorModel = try encoder.encode(mockErrorModel)
        let responseResult = await Mock.Route(session: NetworkingSession(urlSession: Mock.UrlSession(mockResponseData: encodedMockErrorModel)),
                                              responseSerializer: NetworkingResponseSerializers.DecodableResponseWithErrorSerializer<Mock.DecodableModel, Mock.DecodableError>()).task().result
        XCTAssertThrowsError(try responseResult.get()) { error in
            XCTAssertNotNil(error as? Mock.DecodableError)
            XCTAssertEqual(error as? Mock.DecodableError, mockErrorModel)
        }
    }

    func testDoubleDecodingFailure() async throws {

        let unexpectedErrorData = try JSONEncoder().encode(["mockErrorMessage" : "some reason why an error occured"])
        let responseResult = await Mock.Route(session: NetworkingSession(urlSession: Mock.UrlSession(mockResponseData: unexpectedErrorData)),
                                              responseSerializer: NetworkingResponseSerializers.DecodableResponseWithErrorSerializer<Mock.DecodableModel, Mock.DecodableError>()).task().result
        XCTAssertThrowsError(try responseResult.get()) { error in

            let responseSerializerError = error as? NetworkingResponseSerializers.DecodableResponseWithErrorSerializer<Mock.DecodableModel, Mock.DecodableError>.ResponseSerializerError
            guard case .multipleFailures(let responseSerializerErrors) = responseSerializerError else {
                XCTFail("responseSerializerErrors should be .multipleFailures")
                return
            }

            XCTAssertEqual(responseSerializerErrors.count, 2)
            switch (responseSerializerErrors.first, responseSerializerErrors.last) {
                case (.serializingObjectFailure(let decodingDecodableModelError),
                      .serializingErrorObjectFailure(let decodingErrorModelError)):
                    XCTAssertTrue(decodingDecodableModelError is DecodingError)
                    XCTAssertTrue(decodingErrorModelError is DecodingError)
                default:
                    XCTFail("decodingDecodableModelError should be of type .serializingObjectFailure")
            }
        }
    }

    func testNetworkingFailure() async throws {

        let mockNetworkingResponseError = NSError(domain: "mock error", code: 1)
        let responseResult = await Mock.Route(session: NetworkingSession(urlSession: Mock.UrlSession(mockResponseError: mockNetworkingResponseError)),
                                              responseSerializer: NetworkingResponseSerializers.DecodableResponseWithErrorSerializer<Mock.DecodableModel, Mock.DecodableError>()).task().result
        XCTAssertThrowsError(try responseResult.get()) { error in
            XCTAssertEqual(mockNetworkingResponseError, error as NSError)
        }
    }

    func testNilDataFailure() async throws {

        let responseResult = await Mock.Route(responseSerializer: NetworkingResponseSerializers.DecodableResponseWithErrorSerializer<Mock.DecodableModel, Mock.DecodableError>()).task().result
        XCTAssertThrowsError(try responseResult.get()) { error in
            let responseSerializerError = error as? NetworkingResponseSerializers.DecodableResponseWithErrorSerializer<Mock.DecodableModel, Mock.DecodableError>.ResponseSerializerError
            guard case .noData = responseSerializerError else {
                XCTFail("The error should be .noData")
                return
            }
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
