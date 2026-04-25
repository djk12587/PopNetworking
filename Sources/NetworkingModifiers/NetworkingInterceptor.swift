//
//  Networking+Interceptor.swift
//  PopNetworking
//
//  Created by Daniel Koza on 1/9/21.
//  Copyright © 2021 Daniel Koza. All rights reserved.
//

import Foundation

/// Allows you to mutate a request before it gets sent, and retry `URLRequest`'s that failed.
/// - Note:
///   Common use case: refreshing authorization tokens
public protocol NetworkingInterceptor: NetworkingAdapter & NetworkingRetrier {

    /// `priority` determines the order ``NetworkingInterceptor``'s are ran. Higher priority interceptors run first. Default priority is `NetworkingPriority.standard`
    var priority: NetworkingPriority { get }

}

public extension NetworkingInterceptor {
    var priority: NetworkingPriority { .standard }
}

public extension Array where Element == NetworkingInterceptor {
    var sortedByPriority: Self {
        self.sorted(by: { $0.priority > $1.priority })
    }
}
