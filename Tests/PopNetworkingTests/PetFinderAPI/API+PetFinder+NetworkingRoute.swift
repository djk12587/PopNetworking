//
//  API+PetFinder+Network+Route.swift
//  howToUse
//
//  Created by Dan Koza on 2/14/21.
//

import Foundation
import PopNetworking

///https://www.petfinder.com/developers/v2/docs/
protocol PetFinderRoute: NetworkingRoute {
    var requiresAuthentication: Bool { get }
}

extension PetFinderRoute {

    var baseUrl: String { "https://api.petfinder.com" }

    var headers: NetworkingRouteHttpHeaders? {
        guard requiresAuthentication else { return nil }

        let storedAccess = API.PetFinder.StoredApiAccess.apiAccess
        return ["Authorization" : "\(storedAccess.tokenType) \(storedAccess.accessToken)" ]
    }

    var session: NetworkingSession {
        if requiresAuthentication {
            return API.PetFinder.Session.authenticatedSession
        }
        else {
            return NetworkingSession.shared
        }
    }
}
