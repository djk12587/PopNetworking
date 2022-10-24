//
//  File.swift
//  
//
//  Created by Dan Koza on 10/24/22.
//

import Foundation

public protocol NetworkingResponseValidator {
    func validate(result: Result<Data, Error>, urlResponse: HTTPURLResponse?) -> Result<Data, Error>
}
