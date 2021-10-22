//
//  API+PetFinder+Networking+Sessions.swift
//  howToUse
//
//  Created by Dan Koza on 2/14/21.
//

import Foundation
import PopNetworking

extension API.PetFinder {
    enum Session {}
}

extension API.PetFinder.Session {
    ///Use this NetworkingSession for any PetFinder endpoints that require authentication
    static let authenticatedSession: NetworkingSession = {
        return NetworkingSession(accessTokenVerifier: API.PetFinder.PetFinderAccessTokenVerifier())
    }()
}
