//
//  File.swift
//  
//
//  Created by Dan_Koza on 10/21/21.
//

import Foundation

internal class ReauthenticationHandler<AccessTokenVerifier: AccessTokenVerification>: NetworkingRequestInterceptor {

    private var reauthenticationTask: Task<NetworkingRequestRetrierResult, Never>?
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

    func retry(urlRequest: URLRequest, dueTo error: Error, urlResponse: HTTPURLResponse, retryCount: Int) async -> NetworkingRequestRetrierResult {

        guard accessTokenVerifier.shouldReauthenticate(urlRequest: urlRequest, dueTo: error, urlResponse: urlResponse, retryCount: retryCount) else {
            return .doNotRetry
        }

        return await reauthenticate()
    }

    private func reauthenticate() async -> NetworkingRequestRetrierResult {

        if let reauthTask = reauthenticationTask {
            return await reauthTask.value
        }
        else {
            let reauthTask = Task<NetworkingRequestRetrierResult, Never> {
                defer { reauthenticationTask = nil }

                let reauthResult = await accessTokenVerifier.reauthenticationRoute.request.result
                await accessTokenVerifier.reauthenticationCompleted(result: reauthResult)
                switch reauthResult {
                    case .success:
                        return .retry
                    case .failure:
                        return .doNotRetry
                }
            }
            reauthenticationTask = reauthTask
            return await reauthTask.value
        }
    }
}
