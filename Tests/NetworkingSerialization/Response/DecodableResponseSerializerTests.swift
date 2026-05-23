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
        let responseModel = try await Mock.ResponseRoute(session: NetworkingSession(urlSession: Mock.UrlSession(mockResult: .success(encodedModel))),
                                                         serializer: NetworkingSerializers.Response.Decodable<Mock.DecodableModel>()).task().result.get()
        XCTAssertEqual(mockModel, responseModel)
    }

    func testDecodingFailure() async throws {

        let encodedUnexpectedModel = try JSONEncoder().encode("mockModel")
        let responseResult = await Mock.ResponseRoute(session: NetworkingSession(urlSession: Mock.UrlSession(mockResult: .success(encodedUnexpectedModel))),
                                                      serializer: NetworkingSerializers.Response.Decodable<Mock.DecodableModel>()).task().result
        XCTAssertThrowsError(try responseResult.get()) { error in
            XCTAssertNotNil(error as? DecodingError)
        }
    }

    func testNetworkingFailure() async throws {

        let mockNetworkingResponseError = NSError(domain: "mock error", code: 1)
        let responseResult = await Mock.ResponseRoute(session: NetworkingSession(urlSession: Mock.UrlSession(mockResult: .failure(mockNetworkingResponseError))),
                                                      serializer: NetworkingSerializers.Response.Decodable<Mock.DecodableModel>()).task().result
        XCTAssertThrowsError(try responseResult.get()) { error in
            XCTAssertEqual(mockNetworkingResponseError, error as NSError)
        }
    }
}

private extension Mock {
    struct DecodableModel: Codable, Equatable {
        let mockProperty: String
    }
}
