//
//  NetworkingModifierHelpers.swift
//  PopNetworking
//
//  Created by Dan Koza on 7/2/25.
//

import Foundation

/// `NetworkingRetrierResult` indicates if a request should be retried or not. `NetworkingRetrierResult` is returned from ``NetworkingRetrier/retry(urlRequest:dueTo:urlResponse:retryCount:)``.
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
    static let high = NetworkingPriority(Int(Double(Int.max) * 0.5))
    static let standard = NetworkingPriority(0)
    static let low = NetworkingPriority(Int(Double(Int.min) * 0.5))
    static let lowest = NetworkingPriority(Int.min)

}
