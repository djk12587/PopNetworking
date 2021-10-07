//
//  Networking+ResponseSerializers.swift
//  PopNetworking
//
//  Created by Daniel Koza on 1/9/21.
//  Copyright © 2021 Daniel Koza. All rights reserved.
//

import Foundation

public enum NetworkingResponseSerializers {

    /// Attempts to parse response `Data` into a decodable object of type ``DecodableResponseSerializer/SerializedObject`` This class does not handle your API's errors. To handle custom API errors use ``DecodableResponseWithErrorSerializer``
    public struct DecodableResponseSerializer<ResponseType: Decodable>: NetworkingResponseSerializer {

        public typealias SerializedObject = ResponseType

        private let jsonDecoder: JSONDecoder

        /// Use used to convert response `Data` into a `Decodable` ``SerializedObject``
        /// - Parameters:
        ///   - jsonDecoder: The `JSONDecoder` that will be used to decode the `URLSessionDataTask.RawResponse` into the specified ``SerializedObject``
        public init(jsonDecoder: JSONDecoder = JSONDecoder()) {
            self.jsonDecoder = jsonDecoder
        }

        public func serialize(response: URLSessionDataTask.RawResponse) -> Result<SerializedObject, Error> {
            if let error = response.error { return .failure(error) }
            guard let data = response.data else { return .failure(ResponseSerializerError.noData) }
            return Result { try jsonDecoder.decode(SerializedObject.self, from: data) }
        }

        public enum ResponseSerializerError: Error {
            case noData
        }
    }

    /// Attempts to parse response `Data` into a decodable object of type ``DecodableResponseWithErrorSerializer/SerializedObject`` If the ``DecodableResponseWithErrorSerializer/SerializedObject`` fails parsing, then the ``DecodableResponseWithErrorSerializer/SerializedErrorObject`` will attempt to be parsed.
    public struct DecodableResponseWithErrorSerializer<ResponseType: Decodable,
                                                       ResponseErrorType: Decodable & Error>: NetworkingResponseSerializer {

        public typealias SerializedObject = ResponseType
        public typealias SerializedErrorObject = ResponseErrorType

        private let jsonDecoder: JSONDecoder

        /// Use used to convert response `Data` into a `Decodable` ``SerializedObject`` or ``SerializedErrorObject``
        /// - Parameters:
        ///   - jsonDecoder: The `JSONDecoder` that will be used to decode the `URLSessionDataTask.RawResponse` into the specified ``SerializedObject`` or ``SerializedErrorObject``
        public init(jsonDecoder: JSONDecoder = JSONDecoder()) {
            self.jsonDecoder = jsonDecoder
        }

        public func serialize(response: URLSessionDataTask.RawResponse) -> Result<SerializedObject, Error> {

            if let error = response.error { return .failure(error) }
            guard let data = response.data else { return .failure(ResponseSerializerError.noData) }

            do {
                let serializedOjbect = try jsonDecoder.decode(SerializedObject.self, from: data)
                return .success(serializedOjbect)
            }
            catch let serializedObjectError {
                do {
                    let serializedError = try jsonDecoder.decode(SerializedErrorObject.self, from: data)
                    return .failure(serializedError)
                }
                catch let errorSerializerError {
                    return .failure(ResponseSerializerError.multipleFailures([.serializingObjectFailure(error: serializedObjectError),
                                                                              .serializingErrorObjectFailure(error: errorSerializerError)]))
                }
            }
        }

        public enum ResponseSerializerError: Error {
            case noData
            case serializingObjectFailure(error: Error)
            case serializingErrorObjectFailure(error: Error)
            case multipleFailures([ResponseSerializerError])
        }
    }

    /// Returns the `HTTPURLResponse`'s `statusCode`.
    public struct HttpStatusCodeResponseSerializer: NetworkingResponseSerializer {
        public typealias SerializedObject = Int

        public init() {}

        public func serialize(response: URLSessionDataTask.RawResponse) -> Result<SerializedObject, Error> {
            if let error = response.error { return .failure(error) }
            guard let response = response.urlResponse else { return .failure(ResponseSerializerError.httpResponseCodeMissing) }
            return .success(response.statusCode)
        }

        public enum ResponseSerializerError: Error {
            case httpResponseCodeMissing
        }
    }

    /// Returns the `Data` from the HTTP request
    public struct DataResponseSerializer: NetworkingResponseSerializer {
        public typealias SerializedObject = Data

        public init() {}

        public func serialize(response: URLSessionDataTask.RawResponse) -> Result<SerializedObject, Error> {
            if let error = response.error { return .failure(error) }
            guard let data = response.data else { return .failure(ResponseSerializerError.noData) }
            return .success(data)
        }

        public enum ResponseSerializerError: Error {
            case noData
        }
    }
}
