//
//  API+PetFinder+Network+Route.swift
//  howToUse
//
//  Created by Dan Koza on 2/14/21.
//

import Foundation
import PopNetworking

protocol PetFinderRoute: NetworkingRoute {
    var clientId: String { get }
    var clientSecret: String { get }
    var requiresAuthentication: Bool { get }
}

extension PetFinderRoute {

    var baseURL: String { "https://api.petfinder.com" }
    var clientId: String { "B5JZpOg8HskUlBY3WdioJ4yr6EBI3VUvQYpPs9DuLuznGQJUr1" }
    var clientSecret: String { "cfrjhisHn4akQLq1slGMg5kMViXmyvrH0RDvnoht" }

    var headers: [String : String]? {
        guard requiresAuthentication else { return nil }

        let storedAccess = API.PetFinder.StoredApiAccess.apiAccess
        return ["Authorization" : "\(storedAccess.tokenType) \(storedAccess.accessToken)" ]
    }

    var session: NetworkingSession {
        if requiresAuthentication {
            return API.PetFinder.Session.authenticationSession
        }
        else {
            return API.PetFinder.Session.standard
        }
    }
}
