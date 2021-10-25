//
//  File.swift
//  
//
//  Created by Dan_Koza on 10/21/21.
//

import Foundation

internal class ReauthenticationHandler<AccessTokenVerifier: AccessTokenVerification>: NetworkingRequestInterceptor {

    private var isRefreshingToken = false
    private var queuedRequests: [(NetworkingRequestRetrierResult) -> Void] = []
    private let accessTokenVerifier: AccessTokenVerifier

    public init(accessTokenVerifier: AccessTokenVerifier) {
        self.accessTokenVerifier = accessTokenVerifier
    }

    // MARK: - RequestAdapter

    public func adapt(urlRequest: URLRequest) throws -> URLRequest {
        guard accessTokenVerifier.isAuthorizationRequired(for: urlRequest) else { return urlRequest }

        try accessTokenVerifier.validateAccessToken()

        if accessTokenVerifier.isAuthorizationValid(for: urlRequest) {
            return urlRequest
        }

        var urlRequest = urlRequest
        try accessTokenVerifier.setAuthorization(for: &urlRequest)
        return urlRequest
    }

    // MARK: - RequestRetrier

    ///If your request fails due to 401 error, then reauthenticate with the API & return `.retry` to retry the `urlRequest`
    public func retry(urlRequest: URLRequest, dueTo error: Error, urlResponse: HTTPURLResponse, retryCount: Int, completion: @escaping (NetworkingRequestRetrierResult) -> Void) {
        //Check if the error is due to unauthorized access
        guard accessTokenVerifier.shouldReauthenticate(urlRequest: urlRequest, dueTo: error, urlResponse: urlResponse, retryCount: retryCount) else {
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
            let copyOfPendingRequests = self.queuedRequests
            self.queuedRequests.removeAll()

            //trigger the cached completion blocks. This informs the request if it needs to be retried or not.
            copyOfPendingRequests.forEach { $0(succeeded ? .retry : .doNotRetry) }
        }
    }

    // MARK: - Private - Authenticate with your API

    private func performReauthentication(completion: @escaping (_ succeeded: Bool) -> Void) {
        guard !isRefreshingToken else { return }

        isRefreshingToken = true

        _ = accessTokenVerifier.reauthenticationRoute.request { [weak self] authenticationResult in
            self?.accessTokenVerifier.reauthenticationCompleted(result: authenticationResult, finishedProcessingResult: {
                self?.isRefreshingToken = false
                switch authenticationResult {
                    case .success:
                        completion(true)
                    case .failure:
                        completion(false)
                }
            })
        }
    }
}
