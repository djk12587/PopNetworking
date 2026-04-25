//
//  NetworkingRoute+MultipartEncoding.swift
//  PopNetworking
//

import Foundation
#if canImport(UniformTypeIdentifiers)
import UniformTypeIdentifiers
#endif

/// A part of a `multipart/form-data` body.
public enum MultipartPart: Sendable {

    /// A simple text field. Encoded with `Content-Disposition: form-data; name="<name>"`.
    case text(name: String, value: String)

    /// A binary part with explicit `filename` and `mimeType`.
    case data(name: String,
              data: Data,
              filename: String,
              mimeType: String)

    /// A file part read from disk at encode time.
    ///
    /// - `filename` defaults to `fileURL.lastPathComponent`.
    /// - `mimeType` is auto-detected from the file extension on iOS 14+ / macOS 11+ / tvOS 14+ /
    ///   watchOS 7+ / visionOS 1+, and falls back to `application/octet-stream` otherwise.
    case file(name: String,
              fileURL: URL,
              filename: String? = nil,
              mimeType: String? = nil)
}

/// Encodes an array of ``MultipartPart`` as a `multipart/form-data` body on a `URLRequest`.
///
/// The `Content-Type` HTTP header field of an encoded request is set to
/// `multipart/form-data; boundary=<boundary>` unless already set by the caller.
///
/// Filenames containing non-ASCII characters are emitted using both an ASCII-safe `filename="..."`
/// fallback and an RFC 5987 / RFC 8187 `filename*=UTF-8''...` parameter, so modern servers prefer
/// the encoded form while legacy servers fall back to the plain ASCII version.
public struct MultipartEncoding: Sendable {

    /// Returns a `MultipartEncoding` with an auto-generated boundary.
    public static var `default`: MultipartEncoding { MultipartEncoding() }

    /// The boundary string used to delimit parts. RFC 2046 caps boundaries at 70 characters;
    /// the auto-generated default is well under that limit.
    public let boundary: String

    public init(boundary: String = "PopNetworking.boundary.\(UUID().uuidString)") {
        self.boundary = boundary
    }

    public func encode(_ urlRequest: inout URLRequest, with parts: [MultipartPart]) throws {
        if urlRequest.value(forHTTPHeaderField: "Content-Type") == nil {
            urlRequest.setValue("multipart/form-data; boundary=\(self.boundary)",
                                forHTTPHeaderField: "Content-Type")
        }

        var body = Data()
        let crlf = Data("\r\n".utf8)
        let openingDelimiter = Data("--\(self.boundary)\r\n".utf8)
        let closingDelimiter = Data("--\(self.boundary)--\r\n".utf8)

        for part in parts {
            body.append(openingDelimiter)
            try Self.append(part, into: &body)
            body.append(crlf)
        }

        body.append(closingDelimiter)
        urlRequest.httpBody = body
    }

    private static func append(_ part: MultipartPart, into body: inout Data) throws {
        switch part {
            case .text(let name, let value):
                body.append(Data("Content-Disposition: \(Self.contentDisposition(name: name, filename: nil))\r\n\r\n".utf8))
                body.append(Data(value.utf8))

            case .data(let name, let data, let filename, let mimeType):
                body.append(Data("Content-Disposition: \(Self.contentDisposition(name: name, filename: filename))\r\n".utf8))
                body.append(Data("Content-Type: \(mimeType)\r\n\r\n".utf8))
                body.append(data)

            case .file(let name, let fileURL, let filenameOverride, let mimeTypeOverride):
                let filename = filenameOverride ?? fileURL.lastPathComponent
                let mimeType = mimeTypeOverride ?? Self.mimeType(forFileExtension: fileURL.pathExtension)
                let fileData = try Data(contentsOf: fileURL)

                body.append(Data("Content-Disposition: \(Self.contentDisposition(name: name, filename: filename))\r\n".utf8))
                body.append(Data("Content-Type: \(mimeType)\r\n\r\n".utf8))
                body.append(fileData)
        }
    }

    /// Builds a `Content-Disposition` value with quoted-string escaping and optional RFC 5987
    /// encoding for non-ASCII filenames.
    private static func contentDisposition(name: String, filename: String?) -> String {
        var value = "form-data; name=\"\(escapeQuotedString(name))\""
        guard let filename else { return value }

        let asciiFallback = asciiFallback(filename)
        value += "; filename=\"\(escapeQuotedString(asciiFallback))\""

        if asciiFallback != filename {
            value += "; filename*=UTF-8''\(rfc5987Encode(filename))"
        }
        return value
    }

    /// Escapes `"` and `\` per the HTTP `quoted-string` rule (RFC 7230 § 3.2.6 / RFC 6266).
    private static func escapeQuotedString(_ s: String) -> String {
        var out = ""
        out.reserveCapacity(s.count)
        for ch in s {
            if ch == "\\" || ch == "\"" { out.append("\\") }
            out.append(ch)
        }
        return out
    }

    /// Replaces any non-ASCII character with `_` so the result is safe inside a `quoted-string`
    /// and on legacy servers that don't understand RFC 5987.
    private static func asciiFallback(_ s: String) -> String {
        String(s.map { $0.isASCII ? $0 : "_" })
    }

    /// Percent-encodes a string using the `attr-char` set from RFC 5987 § 3.2.1.
    private static func rfc5987Encode(_ s: String) -> String {
        s.addingPercentEncoding(withAllowedCharacters: .rfc5987AttrChars) ?? s
    }

    private static func mimeType(forFileExtension ext: String) -> String {
        guard !ext.isEmpty else { return "application/octet-stream" }
        #if canImport(UniformTypeIdentifiers)
        if #available(iOS 14, macOS 11, tvOS 14, watchOS 7, visionOS 1, *) {
            return UTType(filenameExtension: ext)?.preferredMIMEType ?? "application/octet-stream"
        }
        #endif
        return "application/octet-stream"
    }
}

private extension CharacterSet {
    /// `attr-char` from RFC 5987 § 3.2.1:
    /// ALPHA / DIGIT / "!" / "#" / "$" / "&" / "+" / "-" / "." / "^" / "_" / "`" / "|" / "~"
    static let rfc5987AttrChars: CharacterSet = {
        var set = CharacterSet.alphanumerics
        set.insert(charactersIn: "!#$&+-.^_`|~")
        return set
    }()
}
