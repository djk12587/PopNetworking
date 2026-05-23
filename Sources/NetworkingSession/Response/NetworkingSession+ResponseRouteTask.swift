//
//  ResponseRouteTask.swift
//
//
//  Created by Dan_Koza on 2/8/21.
//

import Foundation

extension NetworkingSession {

    internal struct ResponseRouteTask<Route: NetworkingResponseRoute>: Sendable {

        /// Repeater counter — response-only state. Streaming has no repeater concept and so
        /// doesn't need this actor.
        private actor RepeaterState {
            private(set) var repeatCount = 0
            func incrementRepeatCount() { self.repeatCount += 1 }
            func resetRepeatCount() { self.repeatCount = 0 }
        }

        private let route: Route
        private let routeTask = RouteTask()
        private let repeaterState = RepeaterState()

        internal var adapter: NetworkingAdapter? { self.route.adapter }
        internal var retrier: NetworkingRetrier? { self.route.retrier }
        internal var interceptor: NetworkingInterceptor? { self.route.interceptor }
        internal var observers: [NetworkingTransportObserver] { self.route.observers }

        init(route: Route) {
            self.route = route
        }

        var urlRequestResult: Result<URLRequest, Error> {
            get async {
                await self.routeTask.urlRequestResult {
                    try await self.route.urlRequest
                }
            }
        }

        func executeAdapter(_ adapter: NetworkingAdapter,
                            on urlRequestResult: Result<URLRequest, Error>) async -> Result<URLRequest, Error> {
            await self.routeTask.executeAdapter(adapter, on: urlRequestResult)
        }

        func start(urlRequestResult: Result<URLRequest, Error>,
                   on urlSession: URLSessionProtocol,
                   observers: [NetworkingTransportObserver]) async -> (Result<Route.Serializer.SerializedObject, Error>, URLResponse?) {
            if let mockSerializedResult = self.route.mockSerializedResult {
                return (mockSerializedResult, nil)
            } else {
                let responseResult = await self.executeRequest(urlRequestResult: urlRequestResult,
                                                               on: urlSession,
                                                               observers: observers)
                let serializedResponse = await self.executeResponseSerializer(responseResult: responseResult)

                return (serializedResponse, try? responseResult.get().1)
            }
        }

        /// Evaluates the retrier chain against the attempt's serialized result. On `.success`,
        /// resets the retry counter and returns `.doNotRetry`. On `.failure`, delegates to
        /// ``RouteTask/consultRetriers(error:urlRequest:urlResponse:retriers:)``.
        func executeRetrier(serializedResult: Result<Route.Serializer.SerializedObject, Error>,
                            urlRequest: URLRequest?,
                            urlResponse: URLResponse?,
                            retriers: [NetworkingRetrier]) async -> NetworkingRetrierResult {
            guard case .failure(let error) = serializedResult else {
                await self.routeTask.resetRetryCount()
                return .doNotRetry
            }
            return await self.routeTask.consultRetriers(error: error,
                                                        urlRequest: urlRequest,
                                                        urlResponse: urlResponse,
                                                        retriers: retriers)
        }

        /// Evaluates the route's repeater (if any) against the attempt's terminal state and returns
        /// its decision. Manages `repeatCount` increments and resets.
        func executeRepeater(serializedResult: Result<Route.Serializer.SerializedObject, Error>,
                             urlRequest: URLRequest?,
                             urlResponse: URLResponse?) async -> NetworkingRetrierResult {
            guard let repeater = self.route.repeater else {
                await self.repeaterState.resetRepeatCount()
                return .doNotRetry
            }

            let decision = await repeater(serializedResult,
                                          urlRequest,
                                          urlResponse,
                                          self.repeaterState.repeatCount)
            switch decision {
                case .doNotRetry:
                    await self.repeaterState.resetRepeatCount()
                case .retry, .retryWithDelay:
                    await self.repeaterState.incrementRepeatCount()
            }
            return decision
        }

        /// Executes the `URLRequest` (if available) and notifies `observers` at each lifecycle point. Fires
        /// `willSend` before sending, then exactly one of `didReceive` (transport success) or `didFail`
        /// (transport error). When `urlRequestResult` is already a failure, no observer methods fire.
        ///
        /// All observers for a given lifecycle point fire concurrently. The function still awaits the full
        /// group before returning, so the temporal contract relative to the request (`willSend` before
        /// `URLSession.data(for:)`, `didReceive`/`didFail` before the next attempt) is preserved.
        private func executeRequest(urlRequestResult: Result<URLRequest, Error>,
                                    on urlSession: URLSessionProtocol,
                                    observers: [NetworkingTransportObserver]) async -> Result<(Data, URLResponse), Error> {
            switch urlRequestResult {
                case .failure(let error):
                    return .failure(error)
                case .success(let urlRequest):
                    await observers.notifyConcurrently { await $0.willSend(urlRequest: urlRequest) }
                    do {
                        let (data, urlResponse) = try await urlSession.data(for: urlRequest)
                        await observers.notifyConcurrently { await $0.didReceive(data: data, urlResponse: urlResponse) }
                        return .success((data, urlResponse))
                    } catch {
                        await observers.notifyConcurrently { await $0.didFail(urlRequest: urlRequest, dueTo: error) }
                        return .failure(error)
                    }
            }
        }

        private func executeResponseSerializer(responseResult: Result<(Data, URLResponse), Error>) async -> Result<Route.Serializer.SerializedObject, Error> {
            return await self.route.serializer.serialize(responseResult: responseResult)
        }

    }
}

internal extension Result {
    var error: Error? {
        guard case let .failure(error) = self else { return nil }
        return error
    }
}

internal extension Result where Failure == Error {
    init(asyncCatching: @Sendable () async throws -> Success) async {
        do {
            let success = try await asyncCatching()
            self = .success(success)
        } catch {
            self = .failure(error)
        }
    }
}
