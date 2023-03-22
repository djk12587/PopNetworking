//
//  File.swift
//  
//
//  Created by Dan_Koza on 3/21/23.
//

import Foundation

extension NetworkingSession {
    internal class RouteWebSocketTask<Route: NetworkingRoute>: NSObject, URLSessionWebSocketDelegate {

        private let route: Route
        private var retryCount = 0
        private let urlSessionConfig: URLSessionConfiguration
        private weak var networkingSessionDelegate: NetworkingSessionDelegate?
        private var webSocketOpenedContinuation: CheckedContinuation<Void, Error>?
        private var webSocketResponseContinuation: CheckedContinuation<URLSessionWebSocketTask.Message, Error>?

        init(route: Route,
             urlSessionConfiguration: URLSessionConfiguration,
             networkingSessionDelegate: NetworkingSessionDelegate) {
            self.route = route
            self.networkingSessionDelegate = networkingSessionDelegate
            self.urlSessionConfig = urlSessionConfiguration
        }

        func createWebSocketTask(adapter: NetworkingRequestAdapter?) async -> (Result<(URLSessionWebSocketTask, URLSession), Error>, URLRequest?) {
            let urlRequestResult: Result<URLRequest, Error> = await Result {
                let urlRequest = try route.urlRequest
                let adaptedUrlRequest = try await adapter?.adapt(urlRequest: urlRequest)
                return adaptedUrlRequest ?? urlRequest
            }

            do {
                let urlRequest = try urlRequestResult.get()
                let urlSession = URLSession(configuration: urlSessionConfig, delegate: self, delegateQueue: nil)
                let webSocketTask = urlSession.webSocketTask(with: urlRequest)
                return (.success((webSocketTask, urlSession)), urlRequest)
            }
            catch {
                return (.failure(error), nil)
            }
        }

        func open(_ webSocketCreationResult: Result<(URLSessionWebSocketTask, URLSession), Error>) async throws -> URLSessionWebSocketTask {
            let (webSocketTask, urlSession) = try webSocketCreationResult.get()
            try await withCheckedThrowingContinuation { continuation in
                self.webSocketOpenedContinuation = continuation
                webSocketTask.resume()
                urlSession.finishTasksAndInvalidate()
            }
            return webSocketTask
        }

        func startListening(to webSocketTask: URLSessionWebSocketTask, streamContinuation: AsyncStream<Route.StreamResponse>.Continuation) async throws {

            let webSocketMessage = try await withCheckedThrowingContinuation { continuation in
                self.webSocketResponseContinuation = continuation
                webSocketTask.receive { webSocketResult in
                    continuation.resume(with: webSocketResult)
                }
            }

            do {
                let responseData = try webSocketMessage.convertToData
                try route.responseValidator?.validate(result: .success(responseData),
                                                      urlResponse: webSocketTask.response as? HTTPURLResponse)
                let serializedResponse = route.responseSerializer.serialize(result: .success(responseData),
                                                                            urlResponse: webSocketTask.response as? HTTPURLResponse)
                streamContinuation.yield((response: serializedResponse, task: webSocketTask))
            }
            catch {
                streamContinuation.yield((response: .failure(error), task: webSocketTask))
            }

            try await startListening(to: webSocketTask, streamContinuation: streamContinuation)
        }

        func executeRetrier(retrier: NetworkingRequestRetrier?,
                            error: Error,
                            streamContinuation: AsyncStream<Route.StreamResponse>.Continuation,
                            urlRequest: URLRequest?,
                            response: HTTPURLResponse?) async {
            guard
                let retrier = retrier,
                let networkingSessionDelegate = networkingSessionDelegate
            else {
                retryCount.reset()
                streamContinuation.yield((.failure(error), nil))
                streamContinuation.finish()
                return
            }

            switch await retrier.retry(urlRequest: urlRequest,
                                       dueTo: error,
                                       urlResponse: response,
                                       retryCount: retryCount) {
                case .retry:
                    retryCount.increment()
                    await networkingSessionDelegate.reconnect(to: self,
                                                              streamContinuation: streamContinuation,
                                                              delay: nil)
                case .retryWithDelay(let delay):
                    retryCount.increment()
                    await networkingSessionDelegate.reconnect(to: self,
                                                              streamContinuation: streamContinuation,
                                                              delay: delay)
                case .doNotRetry:
                    retryCount.reset()
                    streamContinuation.yield((.failure(error), nil))
                    streamContinuation.finish()
            }
        }

        func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
            webSocketOpenedContinuation?.resume()
            webSocketOpenedContinuation = nil
        }

        func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
            let webSocketClosedError = NSError(domain: "Web socket connection was closed",
                                               code: closeCode.rawValue,
                                               userInfo: ["Reason": reason ?? "No reason was given".data(using: .utf8) ?? Data()])
            webSocketOpenedContinuation?.resume(throwing: webSocketClosedError)
            webSocketOpenedContinuation = nil
            webSocketResponseContinuation?.resume(throwing: webSocketClosedError)
            webSocketResponseContinuation = nil
        }

        func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
            if let error = error {
                webSocketOpenedContinuation?.resume(throwing: error)
                webSocketOpenedContinuation = nil
            }
        }
    }
}

private extension URLSessionWebSocketTask.Message {
    var convertToData: Data {
        get throws {
            switch self {
                case .data(let data):
                    return data

                case .string(let string):
                    guard let data = string.data(using: .utf8) else { throw NSError(domain: "Web Socket string response could not be converted to data", code: 0) }
                    return data

                @unknown default:
                    throw NSError(domain: "there must be a new enum case that was created in the future... sorry", code: 0)
            }
        }
    }
}
