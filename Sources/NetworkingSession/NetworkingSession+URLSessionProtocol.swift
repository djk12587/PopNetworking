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
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
    func webSocketTask(with: URLRequest) -> URLSessionWebSocketTask
    var configuration: URLSessionConfiguration { get }
}

extension URLSession: URLSessionProtocol {}
