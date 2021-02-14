//
//  API+PetFinder+Network+Routes.swift
//  howToUse
//
//  Created by Dan Koza on 2/14/21.
//

import Foundation
import PopNetworking

extension API {
    enum PetFinder {}
}

extension API.PetFinder {
    enum Routes {}
}

extension API.PetFinder.Routes {

    struct Authenticate: PetFinderRoute {

        let path = "/v2/oauth2/token"
        let method: NetworkingRouteHttpMethod = .post
        let requiresAuthentication = false
        var parameterEncoding: NetworkingRequestParameterEncoding {
            .url(params: ["grant_type" : "client_credentials",
                          "client_id" : "B5JZpOg8HskUlBY3WdioJ4yr6EBI3VUvQYpPs9DuLuznGQJUr1",
                          "client_secret" : "cfrjhisHn4akQLq1slGMg5kMViXmyvrH0RDvnoht"])
        }

        typealias ResponseSerializer = NetworkingResponseSerializers.DecodableResponseWithErrorSerializer<Models.PetFinder.ApiAccess, Models.PetFinder.ApiError>
        let responseSerializer = ResponseSerializer()
    }

    struct GetAnimals: PetFinderRoute {

        let animalType: AnimalType

        let path = "/v2/animals"
        let method: NetworkingRouteHttpMethod = .get
        let requiresAuthentication = true
        var parameterEncoding: NetworkingRequestParameterEncoding {
            .url(params: ["type" : animalType.rawValue])
        }
        
        typealias ResponseSerializer = NetworkingResponseSerializers.DecodableResponseWithErrorSerializer<Models.PetFinder.GetAnimalsResponse, Models.PetFinder.ApiError>
        let responseSerializer = ResponseSerializer()

        enum AnimalType: String {
            case cat = "Cat"
            case dog = "Dog"
            case bird = "Bird"
        }
    }

    struct GetAnimal: PetFinderRoute {
        let animalId: Int

        var path: String { "/v2/animals/\(animalId)"}
        let method: NetworkingRouteHttpMethod = .get
        let requiresAuthentication = true
        let parameterEncoding: NetworkingRequestParameterEncoding = .url(params: nil)

        typealias ResponseSerializer = NetworkingResponseSerializers.DecodableResponseWithErrorSerializer<Models.PetFinder.GetAnimalResponse, Models.PetFinder.ApiError>
        let responseSerializer = ResponseSerializer()
    }
}
