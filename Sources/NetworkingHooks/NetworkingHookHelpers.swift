//
//  NetworkingHookHelpers.swift
//  PopNetworking
//
//  Created by Dan Koza on 7/2/25.
//

import Foundation

/// `NetworkingRetrierResult` indicates whether a route should be retried or not. Used by both
/// ``NetworkingResponseRoute`` (after a serialized failure) and ``NetworkingStreamRoute``
/// (after a connect-time failure).
public enum NetworkingRetrierResult: Sendable {

    case retry
    case retryWithDelay(TimeInterval)
    case doNotRetry

}

public struct NetworkingPriority: Sendable, Comparable {

    private let value: Int

    public init(_ value: Int) {
        self.value = value
    }

    public static func < (lhs: NetworkingPriority, rhs: NetworkingPriority) -> Bool {
        lhs.value < rhs.value
    }

}

public extension NetworkingPriority {

    static let highest = NetworkingPriority(Int.max)
    static let high = NetworkingPriority(Int.max / 2)
    static let standard = NetworkingPriority(0)
    static let low = NetworkingPriority(Int.min / 2)
    static let lowest = NetworkingPriority(Int.min)

}
