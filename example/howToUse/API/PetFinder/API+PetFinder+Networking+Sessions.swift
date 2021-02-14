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
    static let authenticationSession: NetworkingSession = {
        let reauthenticationHandler = API.PetFinder.ReauthenticationHandler()
        let session = NetworkingSession(requestAdapter: reauthenticationHandler,
                                        requestRetrier: reauthenticationHandler)
        return session
    }()

    ///Use this NetworkingSession for any PetFinder endpoints that DO NOT require authentication
    static let standard: NetworkingSession = {
        let session = NetworkingSession()
        return session
    }()
}
