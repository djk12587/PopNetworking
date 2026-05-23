//
//  NetworkingSession+StreamRouteTask.swift
//  PopNetworking
//

import Foundation

@available(iOS 15, macOS 12, tvOS 15, watchOS 8, visionOS 1, *)
extension NetworkingSession {

    /// Per-streaming-route helper that owns connect-attempt state. Mirrors ``ResponseRouteTask``
    /// but trimmed for streaming: no repeater (consumers re-iterate `route.stream` to restart),
    /// and the retrier is consulted on raw connect-time `Error`s rather than on a serialized
    /// terminal result.
    internal struct StreamRouteTask<Route: NetworkingStreamRoute>: Sendable {

        private let route: Route
        private let routeTask = RouteTask()

        internal var adapter: NetworkingAdapter? { self.route.adapter }
        internal var retrier: NetworkingRetrier? { self.route.retrier }
        internal var interceptor: NetworkingInterceptor? { self.route.interceptor }
        internal var observers: [NetworkingTransportObserver] { self.route.observers }
        internal var serializer: Route.Serializer { self.route.serializer }
        internal var byteChunkSize: Int { self.route.byteChunkSize }
        internal var mockChunks: [Result<Data, Error>] { self.route.mockChunks }

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

        /// Consults the retrier chain on a connect-time error. Streaming has no "success"
        /// branch at this layer — by the time we call this, we already have an error.
        func consultRetriers(error: Error,
                             urlRequest: URLRequest?,
                             urlResponse: URLResponse?,
                             retriers: [NetworkingRetrier]) async -> NetworkingRetrierResult {
            await self.routeTask.consultRetriers(error: error,
                                                 urlRequest: urlRequest,
                                                 urlResponse: urlResponse,
                                                 retriers: retriers)
        }
    }
}
