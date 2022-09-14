//
//  File.swift
//  
//
//  Created by Dan_Koza on 11/11/21.
//

import Foundation

/// URLSession cannot be subclassed, so instead we utilize this protocol.
///
/// - Note: `URLSession` adheres to ``URLSessionProtocol``
public protocol URLSessionProtocol {
    @available(iOS 13.0, tvOS 13.0, watchOS 6.0, *)
    func data(for request: URLRequest) async throws -> (Data, URLResponse)

    @available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
    func data(for request: URLRequest, delegate: URLSessionTaskDelegate?) async throws -> (Data, URLResponse)
}

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
extension URLSession: URLSessionProtocol {
    public func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        try await data(for: request, delegate: nil)
    }
}
