//
//  NetworkingAdapter.swift
//  PopNetworking
//
//  Created by Dan Koza on 7/1/25.
//

import Foundation

/// Allows you to modify, the `URLRequest` before it is executed as an HTTP request.
public protocol NetworkingAdapter: Sendable {

    /// `priority` determines the order ``NetworkingAdapter``'s are ran. Higher priority adapters are ran first. Default priority is `NetworkingPriority.standard`
    var priority: NetworkingPriority { get }

    /// A throwable function that accepts a `URLRequest` and will return a potentially modified `URLRequest` or throw an `Error`
    /// - Parameters:
    ///   - urlRequest: Modify this `URLRequest` object if necessary. If no modifications are required simply return the `urlRequest`.
    ///
    /// - Returns: The adapted or modified `URLRequest`.
    func adapt(urlRequest: URLRequest) async throws -> URLRequest
}

public extension NetworkingAdapter {
    var priority: NetworkingPriority { .standard }
}

public extension Array where Element == NetworkingAdapter {
    var sortedByPriority: Self {
        self.sorted(by: { $0.priority > $1.priority })
    }
}
