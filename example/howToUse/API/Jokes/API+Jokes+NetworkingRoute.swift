//
//  File.swift
//  howToUse
//
//  Created by Dan Koza on 2/14/21.
//

import Foundation
import PopNetworking

protocol JokesRoute: NetworkingRoute {}

extension JokesRoute {
    var baseURL: String { "https://official-joke-api.appspot.com" }
    var headers: [String : String]? { nil }
    var session: NetworkingSession { API.Jokes.Session.standard }
}
