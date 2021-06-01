//
//  File.swift
//  
//
//  Created by Dan_Koza on 6/1/21.
//

#if canImport(Combine)

import Foundation
import Combine

@available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, *)
extension NetworkingRoute {

    /// Returns a Combine Publisher for a `NetworkingRoute`. This publisher will `Never` fail and the output is `Result<Route.ResponseSerializer.SerializedObject, Error>`
    public var future: NetworkingRoutePublisher<Self> { NetworkingRoutePublisher(route: self) }

    /// Returns a Combine Publisher for a `NetworkingRoute`. This publisher can fail, and the failure is whatever error comes back from running the `NetworkingRoute`. The successful `Output` is the `NetworkingRoute`'s `SerializedObject`
    public var failableFuture: NetworkingRouteFailablePublisher<Self> { NetworkingRouteFailablePublisher(route: self) }
}

/// A Combine Publisher for a `NetworkingRoute`. This publisher will `Never` fail and the output is `Result<Route.ResponseSerializer.SerializedObject, Error>`
@available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, *)
public struct NetworkingRoutePublisher<Route: NetworkingRoute>: Publisher {

    public typealias Output = Result<Route.ResponseSerializer.SerializedObject, Error>
    public typealias Failure = Never

    private let route: Route

    init(route: Route) {
        self.route = route
    }

    public func receive<S>(subscriber: S) where S : Subscriber, Failure == S.Failure, Output == S.Input {
        subscriber.receive(subscription: Inner(route: route, downstream: subscriber))
    }
}

@available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, *)
private extension NetworkingRoutePublisher {
    final class Inner<Downstream: Subscriber>: Subscription, Combine.Cancellable where Downstream.Input == NetworkingRoutePublisher.Output {

        private var downstream: Downstream?
        private let route: Route
        private var routeCancellable: PopNetworking.Cancellable?

        init(route: Route, downstream: Downstream) {
            self.route = route
            self.downstream = downstream
        }

        func request(_ demand: Subscribers.Demand) {

            guard let downstream = downstream else { return }

            self.downstream = nil

            routeCancellable = route.request { result in
                _ = downstream.receive(result)
                downstream.receive(completion: .finished)
            }
        }

        func cancel() {
            routeCancellable?.cancel()
            downstream = nil
        }
    }
}

/// A Combine Publisher for a `NetworkingRoute`. This publisher can fail, and the failure is whatever error comes back from running the `NetworkingRoute`. The successful `Output` is the `NetworkingRoute`'s `SerializedObject`
@available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, *)
public struct NetworkingRouteFailablePublisher<Route: NetworkingRoute>: Publisher {

    public typealias Output = Route.ResponseSerializer.SerializedObject
    public typealias Failure = Error

    private let route: Route

    public init(route: Route) {
        self.route = route
    }

    public func receive<S>(subscriber: S) where S : Subscriber, Failure == S.Failure, Output == S.Input {
        subscriber.receive(subscription: Inner(route: route, downstream: subscriber))
    }
}

@available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, *)
private extension NetworkingRouteFailablePublisher {
    final class Inner<Downstream: Subscriber>: Subscription, Combine.Cancellable where Downstream.Input == NetworkingRouteFailablePublisher.Output,
                                                                                       Downstream.Failure == NetworkingRouteFailablePublisher.Failure {
        
        private var downstream: Downstream?
        private let route: Route
        private var routeCancellable: PopNetworking.Cancellable?

        init(route: Route, downstream: Downstream) {
            self.route = route
            self.downstream = downstream
        }

        func request(_ demand: Subscribers.Demand) {

            guard let downstream = downstream else { return }
            self.downstream = nil

            routeCancellable = route.request { result in
                switch result {
                    case .success(let responseModel):
                        _ = downstream.receive(responseModel)
                        downstream.receive(completion: .finished)
                    case .failure(let error):
                        downstream.receive(completion: .failure(error))
                }
            }
        }

        func cancel() {
            routeCancellable?.cancel()
            downstream = nil
        }
    }
}

#endif
