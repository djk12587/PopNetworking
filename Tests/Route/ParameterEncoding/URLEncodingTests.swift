//
//  URLEncodingTests.swift
//  PopNetworking
//

import XCTest
@testable import PopNetworking

final class URLEncodingTests: XCTestCase {

    private func makeRequest(method: NetworkingRouteHttpMethod = .get,
                             url: String = "https://example.com/api") -> URLRequest {
        var request = URLRequest(url: URL(string: url)!)
        request.httpMethod = method.rawValue
        return request
    }

    // MARK: - Destination .methodDependent

    func testMethodDependentGetEncodesInQueryString() throws {
        var request = makeRequest(method: .get)

        try URLEncoding.default.encode(&request, with: ["foo": "bar"])

        XCTAssertEqual(request.url?.absoluteString, "https://example.com/api?foo=bar")
        XCTAssertNil(request.httpBody)
        XCTAssertNil(request.value(forHTTPHeaderField: "Content-Type"))
    }

    func testMethodDependentNonGetEncodesInBody() throws {
        for method: NetworkingRouteHttpMethod in [.delete, .put, .patch] {
            var request = makeRequest(method: method)

            try URLEncoding.default.encode(&request, with: ["foo": "bar"])

            XCTAssertEqual(request.url?.absoluteString, "https://example.com/api")
            XCTAssertEqual(request.httpBody.map { String(decoding: $0, as: UTF8.self) }, "foo=bar")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"),
                           "application/x-www-form-urlencoded; charset=utf-8")
        }
    }

    func testMethodDependentPostEncodesInBody() throws {
        var request = makeRequest(method: .post)

        try URLEncoding.default.encode(&request, with: ["foo": "bar"])

        XCTAssertEqual(request.url?.absoluteString, "https://example.com/api")
        XCTAssertEqual(request.httpBody.map { String(decoding: $0, as: UTF8.self) }, "foo=bar")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"),
                       "application/x-www-form-urlencoded; charset=utf-8")
    }

    // MARK: - Destination .queryString

    func testQueryStringDestinationEncodesInURL() throws {
        var request = makeRequest(method: .post)

        try URLEncoding.queryString.encode(&request, with: ["a": "1"])

        XCTAssertTrue(request.url?.absoluteString.contains("a=1") ?? false)
        XCTAssertNil(request.httpBody)
        XCTAssertNil(request.value(forHTTPHeaderField: "Content-Type"))
    }

    // MARK: - Destination .httpBody

    func testHttpBodyDestinationEncodesInBody() throws {
        var request = makeRequest(method: .get)

        try URLEncoding.httpBody.encode(&request, with: ["a": "1"])

        XCTAssertFalse(request.url?.absoluteString.contains("?") ?? true)
        XCTAssertEqual(request.httpBody.map { String(decoding: $0, as: UTF8.self) }, "a=1")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"),
                       "application/x-www-form-urlencoded; charset=utf-8")
    }

    // MARK: - Content-Type

    func testContentTypeIsNotOverridden() throws {
        var request = makeRequest(method: .post)
        request.setValue("custom/type", forHTTPHeaderField: "Content-Type")

        try URLEncoding.default.encode(&request, with: ["foo": "bar"])

        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "custom/type")
    }

    // MARK: - Nil / Empty parameters

    func testNilParametersDoesNothing() throws {
        var request = makeRequest()

        try URLEncoding.default.encode(&request, with: nil)

        XCTAssertEqual(request.url?.absoluteString, "https://example.com/api")
        XCTAssertNil(request.httpBody)
        XCTAssertNil(request.value(forHTTPHeaderField: "Content-Type"))
    }

    func testEmptyDictionaryDoesNothing() throws {
        var request = makeRequest()
        let copy = request

        try URLEncoding.default.encode(&request, with: [:])

        XCTAssertEqual(request.url, copy.url)
        XCTAssertNil(request.httpBody)
        XCTAssertNil(request.value(forHTTPHeaderField: "Content-Type"))
    }

    // MARK: - Array encoding

    func testArrayEncodingBrackets() throws {
        let encoding = URLEncoding(destination: .httpBody, arrayEncoding: .brackets)
        var request = makeRequest(method: .post)

        try encoding.encode(&request, with: ["tags": ["a", "b"]])

        let body = request.httpBody.map { String(decoding: $0, as: UTF8.self) } ?? ""
        XCTAssertTrue(body.contains("tags%5B%5D=a"))
        XCTAssertTrue(body.contains("tags%5B%5D=b"))
    }

    func testArrayEncodingNoBrackets() throws {
        let encoding = URLEncoding(destination: .httpBody, arrayEncoding: .noBrackets)
        var request = makeRequest(method: .post)

        try encoding.encode(&request, with: ["tags": ["a", "b"]])

        let body = request.httpBody.map { String(decoding: $0, as: UTF8.self) } ?? ""
        XCTAssertTrue(body.contains("tags=a"))
        XCTAssertTrue(body.contains("tags=b"))
        XCTAssertFalse(body.contains("tags%5B%5D"))
    }

    // MARK: - Bool encoding

    func testBoolEncodingNumeric() throws {
        let encoding = URLEncoding(destination: .httpBody, boolEncoding: .numeric)
        var request = makeRequest(method: .post)

        try encoding.encode(&request, with: ["on": true, "off": false])

        let body = request.httpBody.map { String(decoding: $0, as: UTF8.self) } ?? ""
        XCTAssertTrue(body.contains("off=0"))
        XCTAssertTrue(body.contains("on=1"))
    }

    func testBoolEncodingLiteral() throws {
        let encoding = URLEncoding(destination: .httpBody, boolEncoding: .literal)
        var request = makeRequest(method: .post)

        try encoding.encode(&request, with: ["on": true, "off": false])

        let body = request.httpBody.map { String(decoding: $0, as: UTF8.self) } ?? ""
        XCTAssertTrue(body.contains("off=false"))
        XCTAssertTrue(body.contains("on=true"))
    }

    // MARK: - Nested dictionary

    func testNestedDictionaryEncoding() throws {
        var request = makeRequest(method: .post)

        try URLEncoding(destination: .httpBody).encode(&request, with: ["user": ["name": "Dan"]])

        let body = request.httpBody.map { String(decoding: $0, as: UTF8.self) } ?? ""
        XCTAssertTrue(body.contains("user%5Bname%5D=Dan"))
    }

    // MARK: - queryComponents unit tests

    func testQueryComponentsWithString() {
        let components = URLEncoding().queryComponents(fromKey: "key", value: "value")

        XCTAssertEqual(components.count, 1)
        XCTAssertEqual(components[0].0, "key")
        XCTAssertEqual(components[0].1, "value")
    }

    func testQueryComponentsWithInt() {
        let components = URLEncoding().queryComponents(fromKey: "count", value: 42)

        XCTAssertEqual(components.count, 1)
        XCTAssertEqual(components[0].0, "count")
        XCTAssertEqual(components[0].1, "42")
    }

    func testQueryComponentsWithBool() {
        let components = URLEncoding().queryComponents(fromKey: "flag", value: true)

        XCTAssertEqual(components[0].1, "1")
    }

    func testQueryComponentsWithNestedDictionary() {
        let dict: [String: any Sendable] = ["name": "Dan"]
        let components = URLEncoding().queryComponents(fromKey: "user", value: dict)

        XCTAssertEqual(components.count, 1)
        XCTAssertEqual(components[0].0, "user%5Bname%5D")
        XCTAssertEqual(components[0].1, "Dan")
    }

    func testQueryComponentsWithArray() {
        let components = URLEncoding().queryComponents(fromKey: "ids", value: [1, 2] as [any Sendable])

        XCTAssertEqual(components.count, 2)
        XCTAssertEqual(components[0].0, "ids%5B%5D")
        XCTAssertEqual(components[1].0, "ids%5B%5D")
    }

    // MARK: - escape

    func testEscapeLeavesUnreservedCharacters() {
        XCTAssertEqual(URLEncoding().escape("abc123-_.~"), "abc123-_.~")
    }

    func testEscapeEncodesReservedCharacters() {
        let escaped = URLEncoding().escape("a+b")
        XCTAssertTrue(escaped.contains("%2B"))
    }

    func testEscapePreservesQuestionMarkAndForwardSlash() {
        // RFC 3986 §3.4: ? and / should not be escaped in query strings
        let escaped = URLEncoding().escape("path/to?query")
        XCTAssertTrue(escaped.contains("/"))
        XCTAssertTrue(escaped.contains("?"))
        XCTAssertFalse(escaped.contains("%2F"))
        XCTAssertFalse(escaped.contains("%3F"))
    }

    // MARK: - Error paths

    func testBadUrlWithQueryStringDestinationThrows() {
        var request = URLRequest(url: URL(string: "https://example.com")!)
        request.url = nil
        request.httpMethod = "GET"

        XCTAssertThrowsError(try URLEncoding.queryString.encode(&request, with: ["foo": "bar"])) { error in
            let urlError = error as? URLError
            XCTAssertEqual(urlError?.code, .badURL)
        }
    }

    // MARK: - Appending to existing query

    func testAppendsToExistingQueryString() throws {
        var request = makeRequest(url: "https://example.com/api?existing=1")

        try URLEncoding.queryString.encode(&request, with: ["new": "2"])

        let url = request.url?.absoluteString ?? ""
        XCTAssertTrue(url.contains("existing=1"))
        XCTAssertTrue(url.contains("new=2"))
    }
}
