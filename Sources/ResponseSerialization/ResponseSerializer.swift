//
//  Networking+ResponseSerializers.swift
//  PopNetworking
//
//  Created by Daniel Koza on 1/8/21.
//  Copyright © 2021 Daniel Koza. All rights reserved.
//

import Foundation

/// ``NetworkingResponseSerializer`` is responsible for parsing the `URLSessionDataTask.RawResponse` into  whatever type ``NetworkingResponseSerializer/SerializedObject`` is set to.
public protocol NetworkingResponseSerializer {
    /// The expected response type of a ``NetworkingRoute``
    associatedtype SerializedObject

    /// Serializes the `URLSessionDataTask.RawResponse` whatever type  ``SerializedObject`` is set to.
    ///
    /// - Parameter response: The raw response of a HTTP request, which includes the original `URLRequest`, the `HTTPURLResponse`, response `Data`, and response `Error`
    /// - Returns: A `Result` type that contains a ``NetworkingResponseSerializer/SerializedObject`` or an `Error`
    func serialize(response: URLSessionDataTask.RawResponse) -> Result<SerializedObject, Error>
}
