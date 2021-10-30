//
//  File.swift
//  
//
//  Created by Dan_Koza on 10/21/21.
//

import Foundation

@available(macOS 10.15, *)
internal class ReauthenticationHandler<AccessTokenVerifier: AccessTokenVerification>: NetworkingRequestInterceptor {

    enum ReauthenticationHandlerError: Error {
        case
    }

    private var isRefreshingToken = false
    private var queuedRequests: [(NetworkingRequestRetrierResult) -> Void] = []
    private var queuedRequests2: [CheckedContinuation<NetworkingRequestRetrierResult, Never>] = []
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

    @available(macOS 10.15.0, *)
    func retry2(urlRequest: URLRequest, dueTo error: Error, urlResponse: HTTPURLResponse, retryCount: Int) async -> NetworkingRequestRetrierResult {

        return await withCheckedContinuation { continuation in

            guard accessTokenVerifier.shouldReauthenticate(urlRequest: urlRequest, dueTo: error, urlResponse: urlResponse, retryCount: retryCount) else {
                return continuation.resume(returning: .doNotRetry)
            }

            withTaskGroup(of: <#T##ChildTaskResult.Type#>, body: <#T##(inout TaskGroup<ChildTaskResult>) async -> GroupResult#>)

            queuedRequests2.append(continuation)

//            guard !isRefreshingToken else { return }

            let reauthSuccess = await performReauthentication2()
//            let copyOfQueuedRequests = self.queuedRequests2
//            queuedRequests2.removeAll()
//            copyOfQueuedRequests.forEach { $0.resume(with: .success(reauthSuccess ? .retry : .doNotRetry)) }

        }



        _ = await withCheckedContinuation { continuation in
            queuedRequests2.append(continuation)
        }

        guard !isRefreshingToken else { return continuedResult }

        let reauthSuccess = await performReauthentication2()
        let copyOfQueuedRequests = self.queuedRequests2
        queuedRequests2.removeAll()
        copyOfQueuedRequests.forEach { $0.resume(with: .success(reauthSuccess ? .retry : .doNotRetry)) }
    }

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

    @available(macOS 10.15.0, *)
    private func performReauthentication2() async -> Bool {
//        guard !isRefreshingToken else { return }
        isRefreshingToken = true

        let reauthenticationResult = await accessTokenVerifier.reauthenticationRoute.asyncTask.result
        await accessTokenVerifier.reauthenticationCompleted2(result: reauthenticationResult)
        isRefreshingToken = false

        switch reauthenticationResult {
            case .success:
                return true
            case .failure:
                return false
        }
    }
}
