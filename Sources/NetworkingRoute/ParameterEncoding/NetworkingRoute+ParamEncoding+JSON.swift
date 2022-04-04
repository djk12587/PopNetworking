//
//  ParameterEncoding.swift
//
//  Copyright (c) 2014-2018 Alamofire Software Foundation (http://alamofire.org/)
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.

//  This param encoding was borrowed & slightly tweaked from Alamofire v5.4.1 specifically ParameterEncoding.swift

import Foundation

// MARK: -

/// Uses `JSONSerialization` to create a JSON representation of the parameters object, which is set as the body of the
/// request. The `Content-Type` HTTP header field of an encoded request is set to `application/json`.
public struct JSONEncoding {
    // MARK: Properties

    /// Returns a `JSONEncoding` instance with default writing options.
    public static var `default`: JSONEncoding { JSONEncoding() }

    /// Returns a `JSONEncoding` instance with `.prettyPrinted` writing options.
    public static var prettyPrinted: JSONEncoding { JSONEncoding(options: .prettyPrinted) }

    /// The options for writing the parameters as JSON data.
    public let options: JSONSerialization.WritingOptions

    // MARK: Initialization

    /// Creates an instance using the specified `WritingOptions`.
    ///
    /// - Parameter options: `JSONSerialization.WritingOptions` to use.
    public init(options: JSONSerialization.WritingOptions = []) {
        self.options = options
    }

    // MARK: Encoding

    public func encode(_ urlRequest: inout URLRequest, with parameters: [String: Any]?) throws {

        guard let parameters = parameters else { return }

        do {
            let data = try JSONSerialization.data(withJSONObject: parameters, options: options)

            if urlRequest.allHTTPHeaderFields?["Content-Type"] == nil {
                urlRequest.allHTTPHeaderFields?.updateValue("application/json", forKey: "Content-Type")
            }

            urlRequest.httpBody = data
        } catch {
            throw error
        }
    }

    public func encode(_ urlRequest: inout URLRequest, with data: Data?) {

        guard let data = data else { return }

        if urlRequest.allHTTPHeaderFields?["Content-Type"] == nil {
            urlRequest.allHTTPHeaderFields?.updateValue("application/json", forKey: "Content-Type")
        }

        urlRequest.httpBody = data
    }
}
