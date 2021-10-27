//
//  Networking+ResponseSerializers.swift
//  PopNetworking
//
//  Created by Daniel Koza on 1/8/21.
//  Copyright © 2021 Daniel Koza. All rights reserved.
//

import Foundation

/// The ``NetworkingResponseSerializer``'s job is to serialize/parse networking response data into whatever type you set for the ``SerializedObject``.
///
/// - Note: An example of a  NetworkingResponseSerializer sets the ``SerializedObject`` to be of type `Decodable`. With this, you can serialize networking response data into one of your preexisting `Decodable` Models. To see how check out ``NetworkingResponseSerializers/DecodableResponseSerializer``.
public protocol NetworkingResponseSerializer {
    /// The type you expect the raw response of a networking request to parse into.
    associatedtype SerializedObject

    /// Serializes the `URLSessionDataTask.RawResponse` into whatever type  ``SerializedObject`` is set to.
    ///
    /// - Parameter response: The raw response of a HTTP request, which includes the original `URLRequest`, the `HTTPURLResponse`, the raw response `Data`, and the response `Error`
    /// - Returns: A `Result` type that contains the ``NetworkingResponseSerializer/SerializedObject`` or an `Error`
    func serialize(response: URLSessionDataTask.RawResponse) -> Result<SerializedObject, Error>
}
