//
//  API+PetFinder+Networking+Reauthentication.swift
//  howToUse
//
//  Created by Dan Koza on 2/14/21.
//

import Foundation
@testable import PopNetworking
import UIKit

extension API.PetFinder {
    struct PetFinderAccessTokenVerifier: AccessTokenVerification {

        var reauthenticationRoute = API.PetFinder.Routes.Authenticate()
        var authToken: Models.PetFinder.ApiAccess { API.PetFinder.StoredApiAccess.apiAccess }
        var accessToken: String { authToken.accessToken }
        var tokenIsExpired: Bool { authToken.expiresIn.compare(Date()) == .orderedAscending }
        var tokenType: String { "Bearer" }

        func extractAuthorizationHeaderKey(from urlRequest: URLRequest) -> String? {
            return "Authorization"
        }

        func shouldRetry(urlRequest: URLRequest, dueTo error: Error, urlResponse: HTTPURLResponse, retryCount: Int) -> Bool {
            let requestIsUnauthorized = urlResponse.statusCode == 401 || (error as? ReauthenticationHandlerError) == .tokenIsInvalid
            return requestIsUnauthorized && retryCount < 3
        }

        mutating func reauthentication(result: Result<Models.PetFinder.ApiAccess, Error>) {
            switch result {
                case .success(let authorizationModel):
                    API.PetFinder.StoredApiAccess.apiAccess = authorizationModel
                case .failure(let error):
                    print("reauthentication failure reason: \(error)")
            }
        }
    }
}
