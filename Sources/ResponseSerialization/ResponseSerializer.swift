//
//  Networking+ResponseSerializers.swift
//  PopNetworking
//
//  Created by Daniel Koza on 1/8/21.
//  Copyright © 2021 Daniel Koza. All rights reserved.
//

import Foundation

/// The ``NetworkingResponseSerializer``'s job is to serialize/parse networking response data into whatever type you set for the ``NetworkingResponseSerializer/SerializedObject``.
///
/// - Note: An example of a NetworkingResponseSerializer is ``NetworkingResponseSerializers/DecodableResponseSerializer``. See more `NetworkingResponseSerializer`'s ``NetworkingResponseSerializers``
public protocol NetworkingResponseSerializer: Sendable {
    /// The type you expect the raw response of a networking request to parse into.
    associatedtype SerializedObject: Sendable

    /// Responsible for serializing the REST response data into a ``NetworkingResponseSerializer/SerializedObject``.
    ///
    /// - Parameters:
    ///     - responseResult: A `Result` type that returns the response `Data` and `URLResponse` or an `Error`
    /// - Returns: A `Result` type that contains the ``NetworkingResponseSerializer/SerializedObject`` or an `Error`
    func serialize(responseResult: Result<(Data, URLResponse), Error>) async -> Result<SerializedObject, Error>
}
