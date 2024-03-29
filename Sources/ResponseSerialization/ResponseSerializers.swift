//
//  Networking+ResponseSerializers.swift
//  PopNetworking
//
//  Created by Daniel Koza on 1/9/21.
//  Copyright © 2021 Daniel Koza. All rights reserved.
//

import Foundation

extension Array: Error where Element: Error {}

/// Contains default implementations of ``NetworkingResponseSerializer``. Such as ``DecodableResponseSerializer``, etc.
public enum NetworkingResponseSerializers {

    /// The `DecodableResponseSerializer` will attempt to parse response `Data` into a the generic `SuccessType`. `SuccessType` must adhere to `Decodable`.
    ///
    /// - Note: `DecodableResponseSerializer` cannot handle API's errors. To handle custom API errors see ``DecodableResponseWithErrorSerializer``
    public struct DecodableResponseSerializer<SuccessType: Decodable>: NetworkingResponseSerializer {

        /// The expected response type of a ``NetworkingRoute``. This type must adhere to `Decodable`
        public typealias SerializedObject = SuccessType

        private let jsonDecoder: JSONDecoder

        /// Initializes an instance of `DecodableResponseSerializer`
        /// - Parameters:
        ///   - jsonDecoder: The `JSONDecoder` that will be used to parse json data
        public init(jsonDecoder: JSONDecoder = JSONDecoder()) {
            self.jsonDecoder = jsonDecoder
        }

        public func serialize(result: Result<Data, Error>, urlResponse: HTTPURLResponse?) -> Result<SuccessType, Error> {
            return result.flatMap { data in
                Result { try jsonDecoder.decode(SerializedObject.self, from: data) }
            }
        }
    }

    /// The `DecodableResponseWithErrorSerializer` will attempt to parse response `Data` into a the generic `SuccessType`.  If your networking request failed, the `DecodableResponseWithErrorSerializer` will also attempt to parse response `Data` into the generic `FailureType`. `FailureType` & `SuccessType` must adhere to  `Decodable`. In addition, `FailureType` must aslo adhere to `Error`.
    public struct DecodableResponseWithErrorSerializer<SuccessType: Decodable,
                                                       FailureType: Decodable & Error>: NetworkingResponseSerializer {

        /// The ``SerializedObject`` must adhere to `Decodable`.
        ///
        /// - Note: Typically this would be one of your existing Model objects. That existing model must already adhere to `Decodable`
        public typealias SerializedObject = SuccessType

        /// The ``SerializedErrorObject`` must adhere to `Decodable` & `Error`.
        ///
        /// - Note: Typically this would be one of your existing API Error models. That existing error model must already adheres to `Decodable` & `Codable`
        public typealias SerializedErrorObject = FailureType

        private let successTypeJsonDecoder: JSONDecoder
        private let failureTypeJsonDecoder: JSONDecoder

        /// Initializes an instance of `DecodableResponseWithErrorSerializer`
        /// - Parameters:
        ///   - jsonDecoder: The `JSONDecoder` that will be used to parse json data
        public init(jsonDecoder: JSONDecoder = JSONDecoder()) {
            successTypeJsonDecoder = jsonDecoder
            failureTypeJsonDecoder = jsonDecoder
        }

        /// Initializes an instance of `DecodableResponseWithErrorSerializer`
        /// - Parameters:
        ///   - successTypeJsonDecoder: The `JSONDecoder` that will be used to parse the `Decodable` `SuccessType`
        ///   - failureTypeJsonDecoder: The `JSONDecoder` that will be used to parse the `Decodable` `FailureType`
        public init(successTypeJsonDecoder: JSONDecoder = JSONDecoder(),
                    failureTypeJsonDecoder: JSONDecoder = JSONDecoder()) {
            self.successTypeJsonDecoder = successTypeJsonDecoder
            self.failureTypeJsonDecoder = failureTypeJsonDecoder
        }

        public func serialize(result: Result<Data, Error>, urlResponse: HTTPURLResponse?) -> Result<SuccessType, Error> {
            return result.flatMap { data in
                do {
                    let serializedObject = try successTypeJsonDecoder.decode(SerializedObject.self, from: data)
                    return .success(serializedObject)
                }
                catch let serializedObjectError {
                    do {
                        let serializedError = try failureTypeJsonDecoder.decode(SerializedErrorObject.self, from: data)
                        return .failure(serializedError)
                    }
                    catch let errorSerializerError {
                        return .failure([serializedObjectError, errorSerializerError])
                    }
                }
            }
        }
    }

    /// The `HttpStatusCodeResponseSerializer` returns the `HTTPURLResponse.statusCode`.
    public struct HttpStatusCodeResponseSerializer: NetworkingResponseSerializer {
        public typealias SerializedObject = Int

        public init() {}

        public func serialize(result: Result<Data, Error>, urlResponse: HTTPURLResponse?) -> Result<Int, Error> {
            return result.flatMap { _ in
                guard let response = urlResponse else { return .failure(URLError(.badServerResponse, userInfo: ["Reason": "urlResponse was nil"])) }
                return .success(response.statusCode)
            }
        }
    }

    /// The `DataResponseSerializer` returns the raw networking `Data` from an HTTP response
    public struct DataResponseSerializer: NetworkingResponseSerializer {
        public typealias SerializedObject = Data

        public init() {}

        public func serialize(result: Result<Data, Error>, urlResponse: HTTPURLResponse?) -> Result<Data, Error> { result }
    }
}
