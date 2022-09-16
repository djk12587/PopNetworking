//
//  File.swift
//  
//
//  Created by Dan_Koza on 10/21/21.
//

import Foundation

/**
 A class that helps ensure a `URLRequest`'s authorization is always up to date. See ``AccessTokenVerification`` for more details.

 ```
 // example usage
 let reauthenticationHandler = ReauthenticationHandler(accessTokenVerifier: yourAccessTokenVerifier())
 let networkingSession = NetworkingSession(requestInterceptor: reauthenticationHandler)
 ```
 */
public actor ReauthenticationHandler<AccessTokenVerifier: AccessTokenVerification>: NetworkingRequestInterceptor {

    private var activeReauthenticationTask: Task<NetworkingRequestRetrierResult, Never>?
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

    public func retry(urlRequest: URLRequest?,
                      dueTo error: Error,
                      urlResponse: HTTPURLResponse?,
                      retryCount: Int) async -> NetworkingRequestRetrierResult {
        let reauthorizationResult = accessTokenVerifier.determineReauthorizationMethod(urlRequest: urlRequest,
                                                                                       dueTo: error,
                                                                                       urlResponse: urlResponse,
                                                                                       retryCount: retryCount)
        switch reauthorizationResult {
            case .refreshAuthorization:
                return await reauthenticate()
            case .retryRequest:
                return .retry
            case .doNothing:
                return .doNotRetry
        }
    }

    private func reauthenticate() async -> NetworkingRequestRetrierResult {

        if let activeReauthenticationTask = activeReauthenticationTask, !activeReauthenticationTask.isCancelled {
            return await activeReauthenticationTask.value
        }
        else {
            let reauthTask = createReauthenticationTask()
            activeReauthenticationTask = reauthTask
            return await reauthTask.value
        }
    }

    private func createReauthenticationTask() -> Task<NetworkingRequestRetrierResult, Never> {
        Task {
            defer { activeReauthenticationTask = nil }

            let reauthResult = await accessTokenVerifier.reauthenticationRoute.result
            let saveWasSuccessful = await accessTokenVerifier.saveReauthentication(result: reauthResult)
            switch reauthResult {
                case .success where saveWasSuccessful:
                    return .retry
                default:
                    return .doNotRetry
            }
        }
    }
}
