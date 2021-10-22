//
//  Models+PetFinder+ApiAccess.swift
//  howToUse
//
//  Created by Dan Koza on 2/14/21.
//

import Foundation

enum Models {
    enum PetFinder {}
}

extension Models.PetFinder {
    struct ApiAccess: Codable {
        let tokenType: String
        let expiration: Date
        let accessToken: String

        private enum CodingKeys: String, CodingKey {
            case tokenType = "token_type"
            case expiration = "expires_in"
            case accessToken = "access_token"
        }
    }

    struct ApiError: Error, Codable {
        let status: Int
        let title: String
        let detail: String
    }

    struct GetAnimalsResponse: Codable {
        let animals: [Animal]
    }

    struct GetAnimalResponse: Codable {
        let animal: Animal
    }

    struct Animal: Codable {
        let id: Int
        let url: URL?
        let species: String?
        let age: String?
        let gender: String?
        let size: String?
        let coat: String?
        let name: String?
        let description: String?
    }
}
