//
//  File.swift
//  
//
//  Created by Dan_Koza on 6/1/21.
//

import Foundation
import Combine

public extension NetworkingRoute {

    /// Returns a Combine Publisher for a ``NetworkingRoute``. This publisher will `Never` fail and the `Output` is `Result<NetworkingRoute.ResponseSerializer.SerializedObject, Error>`
    var publisher: NetworkingRoutePublisher<Self> { NetworkingRoutePublisher(route: self) }

    /// Returns a Combine Publisher for a ``NetworkingRoute``. This publisher can fail, and the failure is whatever error comes back from running the ``NetworkingRoute``. The successful `Output` is the `NetworkingRoute.ResponseSerializer.SerializedObject`
    var failablePublisher: NetworkingRouteFailablePublisher<Self> { NetworkingRouteFailablePublisher(route: self) }
}

/// A Combine Publisher for a ``NetworkingRoute``. This publisher will `Never` fail and the output is `Result<Route.ResponseSerializer.SerializedObject, Error>`
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

private extension NetworkingRoutePublisher {
    final class Inner<Downstream: Subscriber>: Subscription, Combine.Cancellable where Downstream.Input == NetworkingRoutePublisher.Output {

        private var downstream: Downstream?
        private let route: Route
        private var routeTask: Task<Route.ResponseSerializer.SerializedObject, Error>?

        init(route: Route, downstream: Downstream) {
            self.route = route
            self.downstream = downstream
        }

        func request(_ demand: Subscribers.Demand) {

            guard let downstream = downstream else { return }

            self.downstream = nil

            routeTask = route.request { result in
                _ = downstream.receive(result)
                downstream.receive(completion: .finished)
            }
        }

        func cancel() {
            routeTask?.cancel()
            downstream = nil
        }
    }
}

/// A Combine Publisher for a ``NetworkingRoute``. This publisher can fail, and the failure is whatever error comes back from running the ``NetworkingRoute``. The successful `Output` is the `NetworkingRoute.ResponseSerializer.SerializedObject`
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

private extension NetworkingRouteFailablePublisher {
    final class Inner<Downstream: Subscriber>: Subscription, Combine.Cancellable where Downstream.Input == NetworkingRouteFailablePublisher.Output,
                                                                                       Downstream.Failure == NetworkingRouteFailablePublisher.Failure {

        private var downstream: Downstream?
        private let route: Route
        private var routeTask: Task<Route.ResponseSerializer.SerializedObject, Error>?

        init(route: Route, downstream: Downstream) {
            self.route = route
            self.downstream = downstream
        }

        func request(_ demand: Subscribers.Demand) {

            guard let downstream = downstream else { return }
            self.downstream = nil

            routeTask = route.request { result in
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
            routeTask?.cancel()
            downstream = nil
        }
    }
}
