//
//  File.swift
//  
//
//  Created by Dan_Koza on 10/21/21.
//

import Foundation

public class ReauthenticationHandler<AccessTokenVerifier: AccessTokenVerification>: NetworkingRequestInterceptor {

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

        let shouldReauthenticate = accessTokenVerifier.shouldReauthenticate(urlRequest: urlRequest,
                                                                            dueTo: error,
                                                                            urlResponse: urlResponse,
                                                                            retryCount: retryCount)
        return shouldReauthenticate ? await reauthenticate() : .doNotRetry
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

            let reauthResult = await accessTokenVerifier.reauthenticationRoute.task.result
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
