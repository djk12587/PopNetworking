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

    public func retry(urlRequest: URLRequest, dueTo error: Error, urlResponse: HTTPURLResponse, retryCount: Int, completion: @escaping (NetworkingRequestRetrierResult) -> Void) {

        guard accessTokenVerifier.shouldReauthenticate(urlRequest: urlRequest, dueTo: error, urlResponse: urlResponse, retryCount: retryCount) else {
            completion(.doNotRetry)
            return
        }

        queuedRequests.append(completion)

        guard !isRefreshingToken else { return }

        performReauthentication { [weak self] succeeded in
            guard let self = self else { return }

            //this retry() function can be recursive. So, we want to make a copy of requestsWaitingForReauthentication, then call removeAll() on requestsWaitingForReauthentication.
            let copyOfPendingRequests = self.queuedRequests
            self.queuedRequests.removeAll()
            copyOfPendingRequests.forEach { $0(succeeded ? .retry : .doNotRetry) }
        }
    }

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
