//
//  Models+Jokes.swift
//  howToUse
//
//  Created by Dan Koza on 2/14/21.
//

import Foundation

extension Models {
    enum Jokes {}
}

extension Models.Jokes {
    struct Joke: Codable {
        let id: Int
        let type: String
        let setup: String
        let punchline: String
    }
}
