//
//  DefaultResponseSerializerTests.swift
//  
//
//  Created by Dan_Koza on 11/30/21.
//

import XCTest
@testable import PopNetworking

class DecodableResponseSerializerTests: XCTestCase {

    func testSuccess() async throws {

        let mockModel = Mock.DecodableModel(mockProperty: "mock value")
        let encodedModel = try JSONEncoder().encode(mockModel)
        let responseModel = try await Mock.Route(session: NetworkingSession(urlSession: Mock.UrlSession(mockResponseData: encodedModel)),
                                                 responseSerializer: NetworkingResponseSerializers.DecodableResponseSerializer<Mock.DecodableModel>()).task().result.get()
        XCTAssertEqual(mockModel, responseModel)
    }

    func testDecodingFailure() async throws {

        let encodedUnexpectedModel = try JSONEncoder().encode("mockModel")
        let responseResult = await Mock.Route(session: NetworkingSession(urlSession: Mock.UrlSession(mockResponseData: encodedUnexpectedModel)),
                                              responseSerializer: NetworkingResponseSerializers.DecodableResponseSerializer<Mock.DecodableModel>()).task().result
        XCTAssertThrowsError(try responseResult.get()) { error in
            XCTAssertNotNil(error as? DecodingError)
        }
    }

    func testNetworkingFailure() async throws {

        let mockNetworkingResponseError = NSError(domain: "mock error", code: 1)
        let responseResult = await Mock.Route(session: NetworkingSession(urlSession: Mock.UrlSession(mockResponseError: mockNetworkingResponseError)),
                                              responseSerializer: NetworkingResponseSerializers.DecodableResponseSerializer<Mock.DecodableModel>()).task().result
        XCTAssertThrowsError(try responseResult.get()) { error in
            XCTAssertEqual(mockNetworkingResponseError, error as NSError)
        }
    }

    func testNilDataFailure() async throws {

        let responseResult = await Mock.Route(responseSerializer: NetworkingResponseSerializers.DecodableResponseSerializer<Mock.DecodableModel>()).task().result
        XCTAssertThrowsError(try responseResult.get()) { error in
            XCTAssertEqual((error as NSError).code, URLError.cannotParseResponse.rawValue)
        }
    }
}

private extension Mock {
    struct DecodableModel: Codable, Equatable {
        let mockProperty: String
    }
}
