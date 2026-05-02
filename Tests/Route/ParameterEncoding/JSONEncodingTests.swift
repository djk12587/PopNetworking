//
//  JSONEncodingTests.swift
//  PopNetworking
//

import XCTest
@testable import PopNetworking

final class JSONEncodingTests: XCTestCase {

    private func makeRequest(method: NetworkingRouteHttpMethod = .post,
                             url: String = "https://example.com/api") -> URLRequest {
        var request = URLRequest(url: URL(string: url)!)
        request.httpMethod = method.rawValue
        return request
    }

    // MARK: - Basic encoding

    func testEncodesDictionaryAsJSONBody() throws {
        var request = makeRequest()

        try JSONEncoding.default.encode(&request, with: ["name": "Dan", "age": 30])

        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
        let body = try XCTUnwrap(request.httpBody)
        let json = try JSONSerialization.jsonObject(with: body) as? [String: Any]
        XCTAssertEqual(json?["name"] as? String, "Dan")
        XCTAssertEqual(json?["age"] as? Int, 30)
    }

    func testEncodesEmptyDictionary() throws {
        var request = makeRequest()

        try JSONEncoding.default.encode(&request, with: [:])

        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
        let body = try XCTUnwrap(request.httpBody)
        let json = try JSONSerialization.jsonObject(with: body) as? [String: Any]
        XCTAssertEqual(json?.count, 0)
    }

    // MARK: - Content-Type

    func testContentTypeIsNotOverridden() throws {
        var request = makeRequest()
        request.setValue("application/vnd.api+json", forHTTPHeaderField: "Content-Type")

        try JSONEncoding.default.encode(&request, with: ["key": "value"])

        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/vnd.api+json")
    }

    func testContentTypeNotSetForNilParameters() throws {
        var request = makeRequest()

        try JSONEncoding.default.encode(&request, with: nil as [String: any Sendable]?)

        XCTAssertNil(request.httpBody)
        XCTAssertNil(request.value(forHTTPHeaderField: "Content-Type"))
    }

    // MARK: - Nil / Empty parameters

    func testNilParametersDoesNothing() throws {
        var request = makeRequest()
        let copy = request

        try JSONEncoding.default.encode(&request, with: nil as [String: any Sendable]?)

        XCTAssertEqual(request.url, copy.url)
        XCTAssertNil(request.httpBody)
    }

    // MARK: - Pretty printed

    func testPrettyPrintedEncoding() throws {
        var request = makeRequest()

        try JSONEncoding.prettyPrinted.encode(&request, with: ["name": "Dan"])

        let body = try XCTUnwrap(request.httpBody)
        let bodyString = String(decoding: body, as: UTF8.self)
        XCTAssertTrue(bodyString.contains("\n"))
    }

    // MARK: - Raw Data overload

    func testRawDataEncoding() {
        let payload = Data("{\"key\":\"value\"}".utf8)
        var request = makeRequest()

        JSONEncoding.default.encode(&request, with: payload)

        XCTAssertEqual(request.httpBody, payload)
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
    }

    func testNilDataDoesNothing() {
        var request = makeRequest()
        let copy = request

        JSONEncoding.default.encode(&request, with: nil as Data?)

        XCTAssertEqual(request.url, copy.url)
        XCTAssertNil(request.httpBody)
        XCTAssertNil(request.value(forHTTPHeaderField: "Content-Type"))
    }

    func testRawDataPreservesContentType() {
        let payload = Data("{}".utf8)
        var request = makeRequest()
        request.setValue("custom/json", forHTTPHeaderField: "Content-Type")

        JSONEncoding.default.encode(&request, with: payload)

        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "custom/json")
    }

    // MARK: - Error paths

    func testNonJSONCompatibleValueThrows() {
        var request = makeRequest()

        XCTAssertThrowsError(try JSONEncoding.default.encode(&request, with: ["invalid": Data()])) { error in
            XCTAssertEqual((error as? URLError)?.code, .unknown)
            XCTAssertEqual((error as? URLError)?.userInfo["reason"] as? String, "parameters are not valid JSON")
        }
    }
}
