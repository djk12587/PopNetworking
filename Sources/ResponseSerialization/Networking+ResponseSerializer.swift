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

    /// Serialize the response `Data` into the provided type..
    ///
    /// - Parameters:
    ///   - request:  `URLRequest` which was used to perform the request, if any.
    ///   - response: `HTTPURLResponse` received from the server, if any.
    ///   - data:     `Data` returned from the server, if any.
    ///   - error:    `Error` produced by PopNetworking or the underlying `URLSession` during the request. Its normally best practice to return a Result.failure with the supplied error, if it is not nil.
    ///
    /// - Returns:    A Result<`SerializedObject`, Error>. Whatever is returned will be sent to your requests completion handler.
    func serialize(response: NetworkingResponse) -> Result<SerializedObject, Error>
}
