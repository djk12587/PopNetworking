//
//  NetworkingSession+ResponseRoute.swift
//  PopNetworking
//

import Foundation

public extension NetworkingSession {

    /// Performs an HTTP request and parses the HTTP response into the route's serialized object.
    ///
    /// Lifecycle:
    /// 1. Builds the `URLRequest` — (``NetworkingEndpoint/urlRequest``)
    /// 2. Adapts the `URLRequest` — (``NetworkingHooks/adapter``)
    /// 3. Notifies ``NetworkingTransportObserver``s that the request will be sent — (``NetworkingTransportObserver/willSend(urlRequest:)``)
    /// 4. Executes the request via ``URLSessionProtocol/data(for:)``
    /// 5. Notifies observers of the response or transport error — (``NetworkingTransportObserver/didReceive(data:urlResponse:)`` / ``NetworkingTransportObserver/didFail(urlRequest:dueTo:)``)
    /// 6. Serializes the response — (``NetworkingResponseRoute/serializer``)
    /// 7. If an error occurred, consults the retrier chain — (``NetworkingHooks/retrier``)
    /// 8. Repeats the entire lifecycle if the repeater requests it — (``NetworkingResponseRoute/repeater``)
    /// - Parameter route: The ``NetworkingResponseRoute`` to execute.
    /// - Returns: The route's serialized object, or throws an `Error`.
    func execute<ResponseRoute: NetworkingResponseRoute>(route: ResponseRoute) async throws -> ResponseRoute.Serializer.SerializedObject {
        try await self.startResponseRoute(ResponseRouteTask(route: route)).get()
    }
}

private extension NetworkingSession {

    /// Top-level iterative driver. Runs one attempt (adapters + request + retriers) to a terminal
    /// `(result, urlRequest, urlResponse)`, evaluates the repeater against that terminal state, and
    /// either returns or loops for another full attempt.
    func startResponseRoute<ResponseRoute: NetworkingResponseRoute>(
        _ routeDataTask: ResponseRouteTask<ResponseRoute>
    ) async -> Result<ResponseRoute.Serializer.SerializedObject, Error> {
        while true {
            let response = await self.runDataRouteAttempt(routeDataTask)

            switch await routeDataTask.executeRepeater(serializedResult: response.result,
                                                       urlRequest: response.urlRequest,
                                                       urlResponse: response.urlResponse) {
                case .doNotRetry:
                    return response.result
                case .retry:
                    continue
                case .retryWithDelay(let delay):
                    do {
                        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    } catch {
                        return .failure(URLError(.cancelled))
                    }
                    continue
            }
        }
    }

    /// Inner iterative loop: adapt the request, run it, ask the retriers what to do. Returns the
    /// terminal `(result, urlRequest, urlResponse)` for this attempt once the retriers return
    /// `.doNotRetry` (either because nothing failed, or because none of them want to retry).
    func runDataRouteAttempt<ResponseRoute: NetworkingResponseRoute>(
        _ routeDataTask: ResponseRouteTask<ResponseRoute>
    ) async -> (result: Result<ResponseRoute.Serializer.SerializedObject, Error>, urlRequest: URLRequest?, urlResponse: URLResponse?) {
        while true {
            var urlRequestResult = await routeDataTask.urlRequestResult

            for adapter in [self.adapter, routeDataTask.adapter, routeDataTask.interceptor].compactMap({ $0 }).sortedByPriority {
                urlRequestResult = await routeDataTask.executeAdapter(adapter, on: urlRequestResult)
            }

            let urlRequest = try? urlRequestResult.get()
            let observers = self.observers + routeDataTask.observers
            let (serializedResult, urlResponse) = await routeDataTask.start(urlRequestResult: urlRequestResult,
                                                                            on: self._urlSession,
                                                                            observers: observers)

            let retriers = [self.retrier, routeDataTask.retrier, routeDataTask.interceptor].compactMap({ $0 }).sortedByPriority
            let retryDecision = await routeDataTask.executeRetrier(serializedResult: serializedResult,
                                                                   urlRequest: urlRequest,
                                                                   urlResponse: urlResponse,
                                                                   retriers: retriers)

            switch retryDecision {
                case .doNotRetry:
                    return (serializedResult, urlRequest, urlResponse)
                case .retry:
                    continue
                case .retryWithDelay(let delay):
                    do {
                        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    } catch {
                        return (.failure(URLError(.cancelled)), urlRequest, urlResponse)
                    }
                    continue
            }
        }
    }
}
