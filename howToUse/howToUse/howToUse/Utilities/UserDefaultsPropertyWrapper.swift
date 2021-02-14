//
//  UserDefaultsPropertyWrapper.swift
//  howToUse
//
//  Created by Dan Koza on 2/14/21.
//

import Foundation

//This is a helper propertyWrapper to quickly save and retrieve data from UserDefaults.
//WARNING: it is bad practice to save authentication credentials in user defaults.

@propertyWrapper
struct UserDefaults<Value: Codable> {
    let key: String
    let defaultValue: Value
    var container: Foundation.UserDefaults = .standard

    var wrappedValue: Value {
        get {
            let value = try? JSONDecoder().decode(Value.self,
                                                  from: container.data(forKey: key) ?? Data())
            return value ?? defaultValue
        }
        set {
            container.setValue(try? JSONEncoder().encode(newValue), forKey: key)
        }
    }
}
