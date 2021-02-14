//
//  API+Jokes+Networking+Session.swift
//  howToUse
//
//  Created by Dan Koza on 2/14/21.
//

import Foundation
import PopNetworking

extension API.Jokes {
    enum Session {}
}

extension API.Jokes.Session {
    static let standard: NetworkingSession = {
        return NetworkingSession()
    }()
}
