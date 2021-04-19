//
//  Networking+ResponseSerializers.swift
//  PopNetworking
//
//  Created by Daniel Koza on 1/8/21.
//  Copyright © 2021 Daniel Koza. All rights reserved.
//

import Foundation

/// The type to which all data response serializers must conform in order to serialize a response.
public protocol NetworkingResponseSerializer {
    /// The type of serialized object to be created.
    associatedtype SerializedObject

    /// Serializes the `NetworkingRawResponse` into the associatedtype type `SerializedObject`.
    ///
    /// - Parameter response: `response` is tuple of type `NetworkingRawResponse` that contains `(urlRequest: URLRequest?, urlResponse: HTTPURLResponse?, data: Data?, error: Error?)`
    /// - Returns: A `Result` that contains a `SerializedObject` or an `Error`
    func serialize(response: NetworkingRawResponse) -> Result<SerializedObject, Error>
}
