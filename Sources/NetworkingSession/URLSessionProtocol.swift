//
//  File.swift
//  
//
//  Created by Dan_Koza on 11/11/21.
//

import Foundation

/// `URLSessionProtocol` is responsible for executing a `URLRequest` and returning the raw `Data` and `URLResponse`.
///
/// - Note: PopNetworking extends `URLSession` and adheres it to ``URLSessionProtocol``
public protocol URLSessionProtocol: Sendable {

    var session: URLSession { get }
    func data(for request: URLRequest) async throws -> (Data, URLResponse)

}

extension URLSession: URLSessionProtocol {

    public var session: URLSession { self }

}
