//
//  File.swift
//  
//
//  Created by Dan_Koza on 10/21/21.
//

import Foundation

public enum ReauthenticationHandlerError: Error {
    case tokenIsInvalid
}

internal class ReauthenticationHandler<AccessTokenVerifier: AccessTokenVerification>: NetworkingRequestInterceptor {

    private var isRefreshingToken = false
    private var queuedRequests: [(NetworkingRequestRetrierResult) -> Void] = []
    private var accessTokenVerifier: AccessTokenVerifier

    public init(accessTokenVerifier: AccessTokenVerifier) {
        self.accessTokenVerifier = accessTokenVerifier
    }

    // MARK: - RequestAdapter

    ///This gives you a chance to modify the `urlRequest` before it gets sent over the wire. This is the spot where you update the authorization for the `urlRequest`. Or, if you know the access token is expired, then throw an error. That error will get sent to the retry() function allowing you to refresh
    public func adapt(urlRequest: URLRequest) throws -> URLRequest {

        let cachedAuthHeaderValue = "\(accessTokenVerifier.tokenType) \(accessTokenVerifier.accessToken)"

        guard let requestsAuthHeaderValue = accessTokenVerifier.extractAuthorizationHeaderValue(from: urlRequest) else {
            //urlRequest doesnt have the Authorization header, so there is no need to modify it
            return urlRequest
        }

        guard !accessTokenVerifier.tokenIsExpired else {
            //We know the access token is unauthorized, so throw an error. This triggers retry() to be called
            throw ReauthenticationHandlerError.tokenIsInvalid
        }

        if requestsAuthHeaderValue != cachedAuthHeaderValue,
           let requestsAuthHeaderKey = accessTokenVerifier.extractAuthorizationHeaderKey(from: urlRequest) {
            var authorizedRequest = urlRequest
            authorizedRequest.allHTTPHeaderFields?[requestsAuthHeaderKey] = cachedAuthHeaderValue
            return authorizedRequest
        }

        return urlRequest
    }

    // MARK: - RequestRetrier

    ///If your request fails due to 401 error, then reauthenticate with the API & return `.retry` to retry the `urlRequest`
    public func retry(urlRequest: URLRequest, dueTo error: Error, urlResponse: HTTPURLResponse, retryCount: Int, completion: @escaping (NetworkingRequestRetrierResult) -> Void) {
        //Check if the error is due to unauthorized access
        guard accessTokenVerifier.shouldRetry(urlRequest: urlRequest, dueTo: error, urlResponse: urlResponse, retryCount: retryCount) else {
            completion(.doNotRetry)
            return
        }

        //hold onto the completion block so we can wait for performReauthentication to complete
        queuedRequests.append(completion)

        //performReauthentication should run only one at a time
        guard !isRefreshingToken else { return }

        performReauthentication { [weak self] succeeded in
            guard let self = self else { return }

            //this retry() function can be recursive. So, we want to make a copy of requestsWaitingForReauthentication, then call removeAll() on requestsWaitingForReauthentication.
            let temporaryCopy = self.queuedRequests
            self.queuedRequests.removeAll()

            //trigger the cached completion blocks. This informs the request if it needs to be retried or not.
            temporaryCopy.forEach { $0(succeeded ? .retry : .doNotRetry) }
        }
    }

    // MARK: - Private - Authenticate with your API

    private func performReauthentication(completion: @escaping (_ succeeded: Bool) -> Void) {
        guard !isRefreshingToken else { return }

        isRefreshingToken = true

        _ = accessTokenVerifier.reauthenticationRoute.request { [weak self] authenticationResult in
            self?.accessTokenVerifier.reauthenticationCompleted(result: authenticationResult) {
                self?.isRefreshingToken = false
                switch authenticationResult {
                    case .success:
                        completion(true)
                    case .failure:
                        completion(false)
                }
            }
        }
    }
}
