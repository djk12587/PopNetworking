//
//  Networking+ResponseSerializers.swift
//  PopNetworking
//
//  Created by Daniel Koza on 1/9/21.
//  Copyright © 2021 Daniel Koza. All rights reserved.
//

import Foundation

public enum NetworkingResponseSerializers {

    ///Attempts to parse response `Data` into a decodable object of type `ResponseType` or a decodable error of type `ResponseErrorType`
    public class DecodableResponseWithErrorSerializer<ResponseType: Decodable,
                                                      ResponseErrorType: Decodable & Error>: NetworkingResponseSerializer {

        public typealias SerializedObject = ResponseType
        public typealias SerializedErrorObject = ResponseErrorType

        private let jsonDecoder: JSONDecoder

        public init(jsonDecoder: JSONDecoder = JSONDecoder()) {
            self.jsonDecoder = jsonDecoder
        }

        public func serialize(request: URLRequest?, response: HTTPURLResponse?, data: Data?, error: Error?) -> Result<SerializedObject, Error> {

            if let error = error { return .failure(error) }
            guard let data = data else { return .failure(ResponseSerializerError.noData) }

            do {
                let serializedOjbect = try jsonDecoder.decode(SerializedObject.self, from: data)
                return .success(serializedOjbect)
            }
            catch let serializedObjectError {
                do {
                    let serializedError = try jsonDecoder.decode(SerializedErrorObject.self, from: data)
                    return .failure(ResponseSerializerError.errors([serializedError,
                                                                    serializedObjectError]))
                }
                catch let errorSerializerError {
                    return .failure(ResponseSerializerError.errors([errorSerializerError,
                                                                    serializedObjectError]))
                }
            }
        }

        public enum ResponseSerializerError: Error {
            case noData
            case errors([Error])
        }
    }

    ///Attempts to parse response `Data` into a decodable object of type `ResponseType` This class does not parse errors. To parse errors use `DecodableResponseSerializer`
    public class DecodableResponseSerializer<ResponseType: Decodable>: NetworkingResponseSerializer {

        public typealias SerializedObject = ResponseType

        private let jsonDecoder: JSONDecoder

        public init(jsonDecoder: JSONDecoder = JSONDecoder()) {
            self.jsonDecoder = jsonDecoder
        }

        public func serialize(request: URLRequest?, response: HTTPURLResponse?, data: Data?, error: Error?) -> Result<SerializedObject, Error> {

            if let error = error { return .failure(error) }
            guard let data = data else { return .failure(ResponseSerializerError.noData) }

            return Result {
                try jsonDecoder.decode(SerializedObject.self, from: data)
            }
        }

        public enum ResponseSerializerError: Error {
            case noData
        }
    }

    public class HttpStatusCodeResponseSerializer: NetworkingResponseSerializer {
        public typealias SerializedObject = Int

        public init() {}

        public func serialize(request: URLRequest?, response: HTTPURLResponse?, data: Data?, error: Error?) -> Result<SerializedObject, Error> {

            if let error = error { return .failure(error) }
            guard let response = response else { return .failure(ResponseSerializerError.httpResponseCodeMissing) }
            return .success(response.statusCode)
        }

        public enum ResponseSerializerError: Error {
            case httpResponseCodeMissing
        }
    }

    public class DataResponseSerializer: NetworkingResponseSerializer {
        public typealias SerializedObject = Data

        public init() {}

        public func serialize(request: URLRequest?, response: HTTPURLResponse?, data: Data?, error: Error?) -> Result<SerializedObject, Error> {

            if let error = error { return .failure(error) }
            guard let data = data else { return .failure(ResponseSerializerError.noData) }
            return .success(data)
        }

        public enum ResponseSerializerError: Error {
            case noData
        }
    }
}
