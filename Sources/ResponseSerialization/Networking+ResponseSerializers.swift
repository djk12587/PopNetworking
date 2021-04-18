//
//  Networking+ResponseSerializers.swift
//  PopNetworking
//
//  Created by Daniel Koza on 1/9/21.
//  Copyright © 2021 Daniel Koza. All rights reserved.
//

import Foundation

public enum NetworkingResponseSerializers {

    ///Attempts to parse response `Data` into a decodable object of type `ResponseType` This class does not parse errors. To parse errors use `DecodableResponseSerializer`
    public struct DecodableResponseSerializer<ResponseType: Decodable>: NetworkingResponseSerializer {

        public typealias SerializedObject = ResponseType

        private let mockedResult: Result<SerializedObject, Error>?
        private let jsonDecoder: JSONDecoder

        /// Use used to convert response `Data` into a `Decodable` `SerializedObject`
        /// - Parameters:
        ///   - jsonDecoder: `jsonDecoder` will be used to decode the response `Data`.
        ///   - mockedResult: For testing purposes only. If you pass in a `mockedResult`. That `mockedResult` will always be returned by `func serialize(request: URLRequest?, response: HTTPURLResponse?, data: Data?, error: Error?)`.
        public init(jsonDecoder: JSONDecoder = JSONDecoder(), mockedResult: Result<SerializedObject, Error>? = nil) {
            self.jsonDecoder = jsonDecoder
            self.mockedResult = mockedResult
        }

        public func serialize(response: NetworkResponse) -> Result<SerializedObject, Error> {

            if let mockedResult = mockedResult { return mockedResult }
            if let error = response.error { return .failure(error) }
            guard let data = response.data else { return .failure(ResponseSerializerError.noData) }

            return Result {
                try jsonDecoder.decode(SerializedObject.self, from: data)
            }
        }

        public enum ResponseSerializerError: Error {
            case noData
        }
    }

    ///Attempts to parse response `Data` into a decodable object of type `ResponseType` or a decodable error of type `ResponseErrorType`
    public struct DecodableResponseWithErrorSerializer<ResponseType: Decodable,
                                                       ResponseErrorType: Decodable & Error>: NetworkingResponseSerializer {

        public typealias SerializedObject = ResponseType
        public typealias SerializedErrorObject = ResponseErrorType

        private let mockedResult: Result<SerializedObject, Error>?
        private let jsonDecoder: JSONDecoder

        /// Use used to convert response `Data` into a `Decodable` `SerializedObject` or a `SerializedErrorObject`
        /// - Parameters:
        ///   - jsonDecoder: `jsonDecoder` will be used to decode the response `Data`.
        ///   - mockedResult: For testing purposes only. If you pass in a `mockedResult`. That `mockedResult` will always be returned by `func serialize(request: URLRequest?, response: HTTPURLResponse?, data: Data?, error: Error?)`.
        public init(jsonDecoder: JSONDecoder = JSONDecoder(), mockedResult: Result<SerializedObject, Error>? = nil) {
            self.jsonDecoder = jsonDecoder
            self.mockedResult = mockedResult
        }

        public func serialize(response: NetworkResponse) -> Result<SerializedObject, Error> {

            if let mockedResult = mockedResult { return mockedResult }
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

    public struct HttpStatusCodeResponseSerializer: NetworkingResponseSerializer {
        public typealias SerializedObject = Int

        private let mockedResult: Result<SerializedObject, Error>?

        /// Use used to convert a response into a `HTTPURLResponse.statusCode`
        /// - Parameter mockedResult: For testing purposes only. If you pass in a `mockedResult`. That `mockedResult` will always be returned by `func serialize(request: URLRequest?, response: HTTPURLResponse?, data: Data?, error: Error?)`.
        public init(mockedResult: Result<SerializedObject, Error>? = nil) {
            self.mockedResult = mockedResult
        }

        public func serialize(response: NetworkResponse) -> Result<SerializedObject, Error> {

            if let mockedResult = mockedResult { return mockedResult }
            if let error = response.error { return .failure(error) }
            guard let response = response.urlResponse else { return .failure(ResponseSerializerError.httpResponseCodeMissing) }
            return .success(response.statusCode)
        }

        public enum ResponseSerializerError: Error {
            case httpResponseCodeMissing
        }
    }

    public struct DataResponseSerializer: NetworkingResponseSerializer {
        public typealias SerializedObject = Data

        private let mockedResult: Result<SerializedObject, Error>?

        /// - Parameter mockedResult:  For testing purposes only. If you pass in a `mockedResult`. That `mockedResult` will always be returned by `func serialize(request: URLRequest?, response: HTTPURLResponse?, data: Data?, error: Error?)`.
        public init(mockedResult: Result<SerializedObject, Error>? = nil) {
            self.mockedResult = mockedResult
        }

        public func serialize(response: NetworkResponse) -> Result<SerializedObject, Error> {

            if let mockedResult = mockedResult { return mockedResult }
            if let error = response.error { return .failure(error) }
            guard let data = response.data else { return .failure(ResponseSerializerError.noData) }
            return .success(data)
        }

        public enum ResponseSerializerError: Error {
            case noData
        }
    }
}
