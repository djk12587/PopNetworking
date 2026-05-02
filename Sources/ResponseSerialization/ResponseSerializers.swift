//
//  Networking+ResponseSerializers.swift
//  PopNetworking
//
//  Created by Daniel Koza on 1/9/21.
//  Copyright © 2021 Daniel Koza. All rights reserved.
//

import Foundation

/// Contains default implementations of ``NetworkingResponseSerializer``. Such as ``DecodableResponseSerializer``, etc.
public enum NetworkingResponseSerializers {

    /// The `DecodableResponseSerializer` will attempt to parse response `Data` into a the generic `SuccessType`. `SuccessType` must adhere to `Decodable`.
    ///
    /// - Note: `DecodableResponseSerializer` cannot handle API's errors. To handle custom API errors see ``DecodableResponseAndErrorSerializer``
    public struct DecodableResponseSerializer<SuccessType: Decodable & Sendable>: NetworkingResponseSerializer {

        /// The expected response type of a ``NetworkingRoute``. This type must adhere to `Decodable`
        public typealias SerializedObject = SuccessType

        private let jsonDecoder: JSONDecoder

        /// Initializes an instance of `DecodableResponseSerializer`
        /// - Parameters:
        ///   - jsonDecoder: The `JSONDecoder` that will be used to parse json data
        public init(jsonDecoder: JSONDecoder = JSONDecoder()) {
            self.jsonDecoder = jsonDecoder
        }

        public func serialize(responseResult: Result<(Data, URLResponse), Error>) async -> Result<SuccessType, Error> {
            return responseResult.flatMap { (responseData, _) in
                Result { try self.jsonDecoder.decode(SerializedObject.self, from: responseData) }
            }
        }
    }

    /// The ``DecodableResponseAndErrorSerializer`` will attempt to parse response `Data` into a the generic `SuccessType`.  If your networking request failed, the `DecodableResponseAndErrorSerializer` will also attempt to parse response `Data` into the generic `FailureType`. `FailureType` & `SuccessType` must adhere to  `Decodable`. In addition, `FailureType` must also adhere to `Error`.
    public struct DecodableResponseAndErrorSerializer<SuccessType: Decodable & Sendable,
                                                      FailureType: Decodable & Error>: NetworkingResponseSerializer {

        /// The ``NetworkingResponseSerializer/SerializedObject`` must adhere to `Decodable`.
        ///
        /// - Note: Typically this would be one of your existing Model objects. That existing model must already adhere to `Decodable`
        public typealias SerializedObject = SuccessType

        /// The ``SerializedErrorObject`` must adhere to `Decodable` & `Error`.
        ///
        /// - Note: Typically this would be one of your existing API Error models. That existing error model must already adheres to `Decodable` & `Codable`
        public typealias SerializedErrorObject = FailureType

        /// Thrown when the response `Data` can be decoded as neither `SuccessType` nor `FailureType`.
        public struct SerializationError: Error {
            /// The error thrown while attempting to decode the response as `SuccessType`.
            public let successTypeDecodingError: Error
            /// The error thrown while attempting to decode the response as `FailureType`.
            public let failureTypeDecodingError: Error

            public init(successTypeDecodingError: Error, failureTypeDecodingError: Error) {
                self.successTypeDecodingError = successTypeDecodingError
                self.failureTypeDecodingError = failureTypeDecodingError
            }
        }

        private let successTypeJsonDecoder: JSONDecoder
        private let failureTypeJsonDecoder: JSONDecoder

        /// Initializes an instance of `DecodableResponseAndErrorSerializer`
        /// - Parameters:
        ///   - jsonDecoder: The `JSONDecoder` that will be used to parse json data
        public init(jsonDecoder: JSONDecoder = JSONDecoder()) {
            self.successTypeJsonDecoder = jsonDecoder
            self.failureTypeJsonDecoder = jsonDecoder
        }

        /// Initializes an instance of `DecodableResponseAndErrorSerializer`
        /// - Parameters:
        ///   - successTypeJsonDecoder: The `JSONDecoder` that will be used to parse the `Decodable` `SuccessType`
        ///   - failureTypeJsonDecoder: The `JSONDecoder` that will be used to parse the `Decodable` `FailureType`
        public init(successTypeJsonDecoder: JSONDecoder = JSONDecoder(),
                    failureTypeJsonDecoder: JSONDecoder = JSONDecoder()) {
            self.successTypeJsonDecoder = successTypeJsonDecoder
            self.failureTypeJsonDecoder = failureTypeJsonDecoder
        }

        public func serialize(responseResult: Result<(Data, URLResponse), Error>) async -> Result<SuccessType, Error> {
            return responseResult.flatMap { (responseData, _) in
                do {
                    let serializedObject = try self.successTypeJsonDecoder.decode(SerializedObject.self, from: responseData)
                    return .success(serializedObject)
                }
                catch let serializedObjectError {
                    do {
                        let serializedError = try self.failureTypeJsonDecoder.decode(SerializedErrorObject.self, from: responseData)
                        return .failure(serializedError)
                    }
                    catch let errorSerializerError {
                        return .failure(SerializationError(
                            successTypeDecodingError: serializedObjectError,
                            failureTypeDecodingError: errorSerializerError
                        ))
                    }
                }
            }
        }
    }

    /// The `HttpStatusCodeResponseSerializer` returns the `HTTPURLResponse.statusCode`.
    public struct HttpStatusCodeResponseSerializer: NetworkingResponseSerializer {
        public typealias SerializedObject = Int

        public init() {}

        public func serialize(responseResult: Result<(Data, URLResponse), Error>) async -> Result<Int, Error> {
            return responseResult.flatMap { (_, urlResponse) in
                guard let httpUrlResponse = urlResponse as? HTTPURLResponse else { return .failure(URLError(.badServerResponse, userInfo: ["Reason": "urlResponse was nil"])) }
                return .success(httpUrlResponse.statusCode)
            }
        }
    }

    /// The `DataResponseSerializer` returns the raw networking `Data` from an HTTP response
    public struct DataResponseSerializer: NetworkingResponseSerializer {
        public typealias SerializedObject = Data

        public init() {}

        public func serialize(responseResult: Result<(Data, URLResponse), Error>) async -> Result<Data, Error> { responseResult.map({ $0.0 }) }
    }

    /// The `EmptyResponseSerializer` discards the response body and returns `Void` on success.
    ///
    /// Use this for routes whose body you don't care about, such as `HEAD` requests or endpoints that respond with `204 No Content` / `205 Reset Content`. The serializer doesn't validate the body's actual length; it succeeds whenever the underlying request succeeded and propagates any transport error otherwise.
    public struct EmptyResponseSerializer: NetworkingResponseSerializer {
        public typealias SerializedObject = Void

        public init() {}

        public func serialize(responseResult: Result<(Data, URLResponse), Error>) async -> Result<Void, Error> {
            responseResult.map { _ in () }
        }
    }
}
