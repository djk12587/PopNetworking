//
//  File.swift
//  
//
//  Created by Dan Koza on 10/24/22.
//

import Foundation

/// A `responseValidator` can be used to ensure a network response is valid before running your ``NetworkingResponseSerializer``. The `responseValidator` must adhere to ``NetworkingResponseValidator``
public protocol NetworkingResponseValidator: Sendable {
    func validate(result: Result<Data, Error>, urlResponse: HTTPURLResponse?) throws
}
