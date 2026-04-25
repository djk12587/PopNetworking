//
//  File.swift
//  
//
//  Created by Dan Koza on 10/24/22.
//

import Foundation

/// A `responseValidator` can be used to ensure a network response is valid before running your ``NetworkingResponseSerializer``.
public protocol NetworkingResponseValidator: Sendable {
    func validate(responseResult: Result<(Data, URLResponse), Error>) async throws
}
