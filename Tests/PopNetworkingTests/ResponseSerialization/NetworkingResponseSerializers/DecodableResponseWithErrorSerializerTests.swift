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
                                                 responseSerializer: NetworkingResponseSerializers.DecodableResponseWithErrorSerializer<Mock.DecodableModel, Mock.DecodableError>()).asyncTask.result.get()
        XCTAssertEqual(mockModel, responseModel)
    }

    func testDecodingFailure() async throws {

        let mockErrorModel = Mock.DecodableError(mockErrorProperty: "some error description")
        let encoder = JSONEncoder()
        let encodedMockErrorModel = try encoder.encode(mockErrorModel)
        let responseResult = await Mock.Route(session: NetworkingSession(urlSession: Mock.UrlSession(mockResponseData: encodedMockErrorModel)),
                                              responseSerializer: NetworkingResponseSerializers.DecodableResponseWithErrorSerializer<Mock.DecodableModel, Mock.DecodableError>()).asyncTask.result
        XCTAssertThrowsError(try responseResult.get()) { error in
            XCTAssertNotNil(error as? Mock.DecodableError)
            XCTAssertEqual(error as? Mock.DecodableError, mockErrorModel)
        }
    }

    func testDoubleDecodingFailure() async throws {

        let unexpectedData = try JSONEncoder().encode("unexpected data")
        let responseResult = await Mock.Route(session: NetworkingSession(urlSession: Mock.UrlSession(mockResponseData: unexpectedData)),
                                              responseSerializer: NetworkingResponseSerializers.DecodableResponseWithErrorSerializer<Mock.DecodableModel, Mock.DecodableError>()).asyncTask.result
        XCTAssertThrowsError(try responseResult.get()) { error in

            let responseSerializerError = error as? NetworkingResponseSerializers.DecodableResponseWithErrorSerializer<Mock.DecodableModel, Mock.DecodableError>.ResponseSerializerError
            guard case .multipleFailures(let responseSerializerErrors) = responseSerializerError else {
                XCTFail("The error should be .multipleFailures")
                return
            }

            guard let mockDecodableModel = responseSerializerErrors.first else {
                XCTFail("we should have 2 errors returned")
                return
            }

            guard let mockDecodableErrorModel = responseSerializerErrors.last else {
                XCTFail("we should have 2 errors returned")
                return
            }

            switch mockDecodableModel {
                case .noData:
                    XCTFail("error should not be of type .noData")
                case .serializingObjectFailure(let decodingDecodableModelError):
                    XCTAssertTrue(decodingDecodableModelError is DecodingError)
                case .serializingErrorObjectFailure:
                    XCTFail("error should not be of type .serializingErrorObjectFailure")
                case .multipleFailures:
                    XCTFail("error should not be of type .multipleFailures")
            }

            switch mockDecodableErrorModel {
                case .noData:
                    XCTFail("error should not be of type .noData")
                case .serializingObjectFailure:
                    XCTFail("error should not be of type .serializingObjectFailure")
                case .serializingErrorObjectFailure(let decodingErrorModelError):
                    XCTAssertTrue(decodingErrorModelError is DecodingError)
                case .multipleFailures:
                    XCTFail("error should not be of type .multipleFailures")
            }
        }
    }

    func testNetworkingFailure() async throws {

        let mockNetworkingResponseError = NSError(domain: "mock error", code: 1)
        let responseResult = await Mock.Route(session: NetworkingSession(urlSession: Mock.UrlSession(mockResponseError: mockNetworkingResponseError)),
                                              responseSerializer: NetworkingResponseSerializers.DecodableResponseWithErrorSerializer<Mock.DecodableModel, Mock.DecodableError>()).asyncTask.result
        XCTAssertThrowsError(try responseResult.get()) { error in
            XCTAssertEqual(mockNetworkingResponseError, error as NSError)
        }
    }

    func testNilDataFailure() async throws {

        let responseResult = await Mock.Route(responseSerializer: NetworkingResponseSerializers.DecodableResponseWithErrorSerializer<Mock.DecodableModel, Mock.DecodableError>()).asyncTask.result
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
        let mockErrorProperty: String
    }
}
