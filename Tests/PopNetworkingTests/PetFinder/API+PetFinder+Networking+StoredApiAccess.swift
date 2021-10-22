//
//  API+PetFinder+Networking+StoredApiAccess.swift
//  howToUse
//
//  Created by Dan Koza on 2/14/21.
//

import Foundation

extension API.PetFinder {
    enum StoredApiAccess {}
}

extension API.PetFinder.StoredApiAccess {
    static var apiAccess = Models.PetFinder.ApiAccess(tokenType: "Bearer",
                                                      expiresIn: Date(),
                                                      accessToken: "Unauthorized")
}
