//
//  MultipartEncodingTests.swift
//  PopNetworking
//

import XCTest
@testable import PopNetworking

final class MultipartEncodingTests: XCTestCase {

    private let testBoundary = "TestBoundary"

    private func makeRequest() -> URLRequest {
        URLRequest(url: URL(string: "https://example.com/upload")!)
    }

    private func bodyString(_ request: URLRequest) -> String {
        guard let data = request.httpBody else { return "" }
        return String(decoding: data, as: UTF8.self)
    }

    // MARK: - Headers

    func testContentTypeHeaderIsSetWithBoundary() throws {
        var request = makeRequest()
        try MultipartEncoding(boundary: testBoundary).encode(&request, with: [
            .text(name: "field", value: "value")
        ])

        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"),
                       "multipart/form-data; boundary=\(testBoundary)")
    }

    func testContentTypeHeaderIsNotOverridden() throws {
        var request = makeRequest()
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        try MultipartEncoding(boundary: testBoundary).encode(&request, with: [
            .text(name: "field", value: "value")
        ])

        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/octet-stream")
    }

    func testCustomBoundaryIsHonoredInBodyDelimiters() throws {
        var request = makeRequest()
        try MultipartEncoding(boundary: "MyBoundary").encode(&request, with: [
            .text(name: "field", value: "value")
        ])

        let body = bodyString(request)
        XCTAssertTrue(body.contains("--MyBoundary\r\n"))
        XCTAssertTrue(body.hasSuffix("--MyBoundary--\r\n"))
    }

    // MARK: - Text part

    func testTextPartEncoding() throws {
        var request = makeRequest()
        try MultipartEncoding(boundary: testBoundary).encode(&request, with: [
            .text(name: "username", value: "Dan")
        ])

        let expected =
            "--\(testBoundary)\r\n" +
            "Content-Disposition: form-data; name=\"username\"\r\n" +
            "\r\n" +
            "Dan\r\n" +
            "--\(testBoundary)--\r\n"
        XCTAssertEqual(bodyString(request), expected)
    }

    // MARK: - Data part

    func testDataPartEncoding() throws {
        let payload = Data([0xDE, 0xAD, 0xBE, 0xEF])
        var request = makeRequest()
        try MultipartEncoding(boundary: testBoundary).encode(&request, with: [
            .data(name: "avatar", data: payload, filename: "a.png", mimeType: "image/png")
        ])

        let header =
            "--\(testBoundary)\r\n" +
            "Content-Disposition: form-data; name=\"avatar\"; filename=\"a.png\"\r\n" +
            "Content-Type: image/png\r\n" +
            "\r\n"
        let trailer = "\r\n--\(testBoundary)--\r\n"

        var expected = Data(header.utf8)
        expected.append(payload)
        expected.append(Data(trailer.utf8))
        XCTAssertEqual(request.httpBody, expected)
    }

    // MARK: - File part

    func testFilePartReadsFileAndUsesDefaults() throws {
        let payload = Data("file contents".utf8)
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(UUID().uuidString).txt")
        try payload.write(to: fileURL)
        defer { try? FileManager.default.removeItem(at: fileURL) }

        var request = makeRequest()
        try MultipartEncoding(boundary: testBoundary).encode(&request, with: [
            .file(name: "report", fileURL: fileURL)
        ])

        let body = bodyString(request)
        XCTAssertTrue(body.contains("Content-Disposition: form-data; name=\"report\"; filename=\"\(fileURL.lastPathComponent)\"\r\n"))
        XCTAssertTrue(body.contains("file contents"))
    }

    func testFilePartHonorsFilenameAndMimeOverrides() throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(UUID().uuidString).bin")
        try Data("xx".utf8).write(to: fileURL)
        defer { try? FileManager.default.removeItem(at: fileURL) }

        var request = makeRequest()
        try MultipartEncoding(boundary: testBoundary).encode(&request, with: [
            .file(name: "doc", fileURL: fileURL, filename: "override.txt", mimeType: "text/plain")
        ])

        let body = bodyString(request)
        XCTAssertTrue(body.contains("filename=\"override.txt\""))
        XCTAssertTrue(body.contains("Content-Type: text/plain"))
    }

    func testFilePartThrowsForMissingFile() {
        let missing = FileManager.default.temporaryDirectory
            .appendingPathComponent("does-not-exist-\(UUID().uuidString)")
        var request = makeRequest()

        XCTAssertThrowsError(try MultipartEncoding(boundary: testBoundary).encode(&request, with: [
            .file(name: "x", fileURL: missing)
        ]))
    }

    // MARK: - Multiple parts / closing delimiter

    func testMultiplePartsAreSeparatedByOpeningBoundaryAndTerminatedByClosing() throws {
        var request = makeRequest()
        try MultipartEncoding(boundary: testBoundary).encode(&request, with: [
            .text(name: "a", value: "1"),
            .text(name: "b", value: "2")
        ])

        let expected =
            "--\(testBoundary)\r\n" +
            "Content-Disposition: form-data; name=\"a\"\r\n\r\n1\r\n" +
            "--\(testBoundary)\r\n" +
            "Content-Disposition: form-data; name=\"b\"\r\n\r\n2\r\n" +
            "--\(testBoundary)--\r\n"
        XCTAssertEqual(bodyString(request), expected)
    }

    func testEmptyPartsArrayProducesOnlyClosingDelimiter() throws {
        var request = makeRequest()
        try MultipartEncoding(boundary: testBoundary).encode(&request, with: [])

        XCTAssertEqual(bodyString(request), "--\(testBoundary)--\r\n")
    }

    // MARK: - RFC 5987 / quoted-string escaping

    func testNonAsciiFilenameEmitsBothPlainAndRfc5987Forms() throws {
        var request = makeRequest()
        try MultipartEncoding(boundary: testBoundary).encode(&request, with: [
            .data(name: "avatar", data: Data("x".utf8), filename: "héllo.png", mimeType: "image/png")
        ])

        let body = bodyString(request)
        XCTAssertTrue(body.contains("filename=\"h_llo.png\""),
                      "Expected ASCII-fallback filename in plain `filename` parameter")
        XCTAssertTrue(body.contains("filename*=UTF-8''h%C3%A9llo.png"),
                      "Expected RFC 5987 percent-encoded filename in `filename*` parameter")
    }

    func testAsciiFilenameDoesNotEmitRfc5987Form() throws {
        var request = makeRequest()
        try MultipartEncoding(boundary: testBoundary).encode(&request, with: [
            .data(name: "avatar", data: Data("x".utf8), filename: "hello.png", mimeType: "image/png")
        ])

        let body = bodyString(request)
        XCTAssertTrue(body.contains("filename=\"hello.png\""))
        XCTAssertFalse(body.contains("filename*="),
                       "Pure ASCII filenames should not emit a `filename*` parameter")
    }

    func testQuoteAndBackslashInFilenameAreEscaped() throws {
        var request = makeRequest()
        try MultipartEncoding(boundary: testBoundary).encode(&request, with: [
            .data(name: "f", data: Data("x".utf8), filename: "a\"b\\c.txt", mimeType: "text/plain")
        ])

        let body = bodyString(request)
        XCTAssertTrue(body.contains(#"filename="a\"b\\c.txt""#))
    }

    // MARK: - URL params alongside

    func testUrlParamsAreAppendedAlongsideMultipart() throws {
        let encoding: NetworkingRouteParameterEncoding = .multipart(
            parts: [.text(name: "field", value: "value")],
            encoder: MultipartEncoding(boundary: testBoundary),
            urlParams: ["v": "1", "src": "ios"]
        )

        var request = URLRequest(url: URL(string: "https://example.com/upload")!)
        request.httpMethod = "POST"
        try encoding.encodeParams(into: &request)

        let urlString = request.url?.absoluteString ?? ""
        XCTAssertTrue(urlString.contains("src=ios"))
        XCTAssertTrue(urlString.contains("v=1"))
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"),
                       "multipart/form-data; boundary=\(testBoundary)")
        XCTAssertNotNil(request.httpBody)
    }
}
