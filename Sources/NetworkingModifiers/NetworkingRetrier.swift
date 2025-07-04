//
//  NetworkingRetrier.swift
//  PopNetworking
//
//  Created by Dan Koza on 7/1/25.
//

import Foundation

/// Allows you to retry a failed `URLRequest`. IE, if the `URLRequest` failed due to a 401 Unauthorized error.
public protocol NetworkingRetrier: Sendable {

    /// `priority` determines the order ``NetworkingRetrier``'s are ran. Higher priority retriers are ran first. Default priority is `NetworkingPriority.standard`
    var priority: NetworkingPriority { get }

    /// A function that will determine if a `URLRequest` should be retried or not.
    ///
    /// - Parameters:
    ///   - urlRequest: The `URLRequest` object that failed.
    ///   - error: The reason the `URLRequest` failed.
    ///   - urlResponse: The failed `URLRequest`'s response.
    ///   - retryCount: The number of times this `URLRequest` has been retried.
    ///
    /// - Returns: An instance of ``NetworkingRetrierResult`` which indicates if the request should be retried or not
    func retry(urlRequest: URLRequest?,
               dueTo error: Error,
               urlResponse: URLResponse?,
               retryCount: Int) async -> NetworkingRetrierResult
}

public extension NetworkingRetrier {
    var priority: NetworkingPriority { .standard }
}

public extension Array where Element == NetworkingRetrier {
    var sortedByPriority: Self {
        self.sorted(by: { $0.priority > $1.priority })
    }
}
