//
//  File.swift
//  
//
//  Created by Dan_Koza on 10/10/21.
//

import XCTest
@testable import PopNetworking

final class ReauthenticationTests: XCTestCase {
    func testReauthentication() throws {

        API.PetFinder.StoredApiAccess.apiAccess = Models.PetFinder.ApiAccess(tokenType: "Bearer",
                                                                             expiration: Date(timeIntervalSinceNow: -10),
                                                                             accessToken: "Unauthorized")

        let endpointWillfinished = expectation(description: "first")
        API.PetFinder.Routes.GetAnimals(animalType: .bird).request { _ in
            endpointWillfinished.fulfill()
        }

        waitForExpectations(timeout: 10)
        XCTAssertNotEqual("Unauthorized", API.PetFinder.StoredApiAccess.apiAccess.accessToken)
    }
}
