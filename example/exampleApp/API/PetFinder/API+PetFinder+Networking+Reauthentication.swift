//
//  API+PetFinder+Networking+Reauthentication.swift
//  howToUse
//
//  Created by Dan Koza on 2/14/21.
//

import Foundation
import PopNetworking

extension API.PetFinder {

    class ReauthenticationHandler: NetworkingRequestInterceptor {

        private typealias RefreshCompletion = (_ succeeded: Bool) -> Void

        private let lock = NSLock()
        private var isRefreshingToken = false
        private var unAuthorizedRequestsToRetry: [(NetworkingRequestRetrierResult) -> Void] = []
        private let maxRetryCount = 3

        // MARK: - RequestAdapter

        ///This gives you a chance to modify the `urlRequest` before it gets sent over the wire
        func adapt(urlRequest: URLRequest, for session: URLSession) -> URLRequest {

            let storedApiAccess = API.PetFinder.StoredApiAccess.apiAccess
            let savedAccesToken = "\(storedApiAccess.tokenType) \(storedApiAccess.accessToken)"

            //Check if the urlRequest's accessToken differs from what the app has saved
            guard let requestsAccessToken = urlRequest.allHTTPHeaderFields?["Authorization"],
                  requestsAccessToken != savedAccesToken else {
                return urlRequest
            }

            var request = urlRequest
            //Update the requests Authorization header with the new accessToken
            request.allHTTPHeaderFields?["Authorization"] = savedAccesToken
            return request
        }

        // MARK: - RequestRetrier

        ///If your request fails due to 401 error, then reauthenticate with the API & return `.retry` to retry the `urlRequest`
        func retry(urlRequest: URLRequest, dueTo error: Error, urlResponse: HTTPURLResponse, retryCount: Int, completion: @escaping (NetworkingRequestRetrierResult) -> Void) {

            lock.lock(); defer { lock.unlock() }

            //Check if the error is due to unauthorized access
            guard urlResponse.statusCode == 401,
                  retryCount < maxRetryCount else {
                completion(.doNotRetry)
                return
            }

            //hold onto the completion block so we can wait for performRefresh to complete
            unAuthorizedRequestsToRetry.append(completion)

            //We only want performRefresh to get called one at a time
            guard !isRefreshingToken else { return }

            performRefresh { [weak self] succeeded in
                guard let self = self else { return }
                self.lock.lock(); defer { self.lock.unlock() }

                //trigger the cached completion blocks. This informs the request if it needs to be retried or not.
                self.unAuthorizedRequestsToRetry.forEach { $0(succeeded ? .retry : .doNotRetry) }
                self.unAuthorizedRequestsToRetry.removeAll()
            }
        }

        // MARK: - Private - Authenticate with your API

        private func performRefresh(completion: @escaping RefreshCompletion) {
            guard !isRefreshingToken else { return }

            isRefreshingToken = true

            API.PetFinder.Routes.Authenticate().request { [weak self] authenticationResult in
                guard case .success(let petFinderAuth) = authenticationResult else {
                    self?.isRefreshingToken = false
                    completion(false)
                    return
                }

                API.PetFinder.StoredApiAccess.apiAccess = petFinderAuth
                self?.isRefreshingToken = false
                completion(true)
            }
        }
    }
}
