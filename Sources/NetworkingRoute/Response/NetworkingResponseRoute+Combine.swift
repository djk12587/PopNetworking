//
//  File.swift
//
//
//  Created by Dan_Koza on 6/1/21.
//

import Foundation
@preconcurrency import Combine

public extension NetworkingResponseRoute {

    /// Returns a Combine Publisher for a ``NetworkingResponseRoute``. This publisher will `Never` fail and the `Output` is `Result<NetworkingResponseRoute.Serializer.SerializedObject, Error>`
    var publisher: NetworkingResponseRoutePublisher<Self> { NetworkingResponseRoutePublisher(route: self) }

    /// Returns a Combine Publisher for a ``NetworkingResponseRoute``. This publisher can fail, and the failure is whatever error comes back from running the ``NetworkingResponseRoute``. The successful `Output` is the `NetworkingResponseRoute.Serializer.SerializedObject`
    var failablePublisher: NetworkingResponseRouteFailablePublisher<Self> { NetworkingResponseRouteFailablePublisher(route: self) }
}

/// A Combine Publisher for a ``NetworkingResponseRoute``. This publisher will `Never` fail and the output is `Result<NetworkingResponseRoute.Serializer.SerializedObject, Error>`
public struct NetworkingResponseRoutePublisher<ResponseRoute: NetworkingResponseRoute>: Publisher {

    public typealias Output = Result<ResponseRoute.Serializer.SerializedObject, Error>
    public typealias Failure = Never

    private let route: ResponseRoute

    init(route: ResponseRoute) {
        self.route = route
    }

    public func receive<S>(subscriber: S) where S: Subscriber,
                                                S: Sendable,
                                                Failure == S.Failure,
                                                Output == S.Input {
        subscriber.receive(subscription: RouteSubscription(route: route, downstream: subscriber) { result, downstream in
            _ = downstream.receive(result)
            downstream.receive(completion: .finished)
        })
    }
}

/// A Combine Publisher for a ``NetworkingResponseRoute``. This publisher can fail, and the failure is whatever error comes back from running the ``NetworkingResponseRoute``. The successful `Output` is the `NetworkingResponseRoute.Serializer.SerializedObject`
public struct NetworkingResponseRouteFailablePublisher<ResponseRoute: NetworkingResponseRoute & Sendable>: Publisher {

    public typealias Output = ResponseRoute.Serializer.SerializedObject
    public typealias Failure = Error

    private let route: ResponseRoute

    public init(route: ResponseRoute) {
        self.route = route
    }

    public func receive<S>(subscriber: S) where S: Subscriber,
                                                S: Sendable,
                                                Failure == S.Failure,
                                                Output == S.Input,
                                                S.Input: Sendable {
        subscriber.receive(subscription: RouteSubscription(route: route, downstream: subscriber) { result, downstream in
            switch result {
                case .success(let responseModel):
                    _ = downstream.receive(responseModel)
                    downstream.receive(completion: .finished)
                case .failure(let error):
                    downstream.receive(completion: .failure(error))
            }
        })
    }
}

private struct RouteSubscription<ResponseRoute: NetworkingResponseRoute, Downstream: Subscriber & Sendable>: Subscription, Combine.Cancellable, Sendable {

    typealias Deliver = @Sendable (Result<ResponseRoute.Serializer.SerializedObject, Error>, Downstream) -> Void

    private actor SafeMutableProperties {

        private(set) var downstream: Downstream?
        private(set) var routeTask: Task<ResponseRoute.Serializer.SerializedObject, Error>?
        private(set) var isCancelled = false

        init(downstream: Downstream?) {
            self.downstream = downstream
        }

        func clearDownstream() {
            self.downstream = nil
        }

        func set(routeTask: Task<ResponseRoute.Serializer.SerializedObject, Error>?) {
            if self.isCancelled {
                routeTask?.cancel()
                return
            }
            self.routeTask = routeTask
        }

        func cancelRoute() {
            self.isCancelled = true
            self.routeTask?.cancel()
            self.routeTask = nil
        }
    }

    let combineIdentifier = CombineIdentifier()
    private let route: ResponseRoute
    private let mutableProperties: SafeMutableProperties
    private let deliver: Deliver

    init(route: ResponseRoute, downstream: Downstream, deliver: @escaping Deliver) {
        self.route = route
        self.mutableProperties = SafeMutableProperties(downstream: downstream)
        self.deliver = deliver
    }

    func request(_ demand: Subscribers.Demand) {
        guard demand > .none else { return }

        Task {
            guard let downstream = await self.mutableProperties.downstream else { return }
            await self.mutableProperties.clearDownstream()
            await self.mutableProperties.set(routeTask: self.route.request { result in
                self.deliver(result, downstream)
            })
        }
    }

    func cancel() {
        Task {
            await self.mutableProperties.cancelRoute()
            await self.mutableProperties.clearDownstream()
        }
    }
}
