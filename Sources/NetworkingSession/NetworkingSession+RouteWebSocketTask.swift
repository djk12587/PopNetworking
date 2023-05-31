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
        private var webSocketConnectionOpenedContinuation: CheckedContinuation<Void, Error>?
        private var webSocketConnectionClosedContinuation: CheckedContinuation<Void, Error>?

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
                webSocketConnectionOpenedContinuation = continuation
                webSocketTask.resume()
                urlSession.finishTasksAndInvalidate()
            }
            return webSocketTask
        }

        func startListening(to webSocketTask: URLSessionWebSocketTask, streamContinuation: AsyncStream<Route.StreamResponse>.Continuation) async {
            do {
                let webSocketMessage = try await webSocketTask.receive()
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

            // .invalid means the websocketTask is still open
            if webSocketTask.closeCode == .invalid {
                await startListening(to: webSocketTask, streamContinuation: streamContinuation)
            }
        }

        func connectionClosed() async throws {
            try await withCheckedThrowingContinuation { continuation in
                webSocketConnectionClosedContinuation = continuation
            }
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
            webSocketConnectionOpenedContinuation?.resume()
            webSocketConnectionOpenedContinuation = nil
        }

        func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
            let webSocketClosedError = NSError(domain: "Web socket connection was closed",
                                               code: closeCode.rawValue,
                                               userInfo: ["Reason": reason ?? "No reason was given".data(using: .utf8) ?? Data()])
            webSocketConnectionOpenedContinuation?.resume(throwing: webSocketClosedError)
            webSocketConnectionOpenedContinuation = nil
            webSocketConnectionClosedContinuation?.resume(throwing: webSocketClosedError)
            webSocketConnectionClosedContinuation = nil
        }

        func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
            if let error = error {
                webSocketConnectionOpenedContinuation?.resume(throwing: error)
                webSocketConnectionOpenedContinuation = nil
                webSocketConnectionClosedContinuation?.resume(throwing: error)
                webSocketConnectionClosedContinuation = nil
            } else {
                webSocketConnectionClosedContinuation?.resume()
                webSocketConnectionClosedContinuation = nil
            }
        }

        //Temporary solution to work with invalid ssl certs, maybe don't use this in prod?
        func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge) async -> (URLSession.AuthChallengeDisposition, URLCredential?) {
            guard let serverTrust = challenge.protectionSpace.serverTrust else { return (.performDefaultHandling, nil) }
            return (.useCredential, URLCredential(trust: serverTrust))
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
