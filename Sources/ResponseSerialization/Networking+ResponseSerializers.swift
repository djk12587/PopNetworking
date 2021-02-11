//
//  Networking+ResponseSerializers.swift
//  CrustyNetworking
//
//  Created by Daniel Koza on 1/9/21.
//  Copyright © 2021 Daniel Koza. All rights reserved.
//

import Foundation

public enum NetworkingResponseSerializers {

    public class DecodableResponseSerializer<ResponseType: Decodable,
                                             ResponseErrorType: Decodable & Error>: NetworkingResponseSerializer {

        public typealias SerializedObject = ResponseType
        public typealias SerializedErrorObject = ResponseErrorType

        private let jsonDecoder: JSONDecoder

        public init(jsonDecoder: JSONDecoder = JSONDecoder()) {
            self.jsonDecoder = jsonDecoder
        }

        public func serialize(request: URLRequest?, response: HTTPURLResponse?, data: Data?, error: Error?) throws -> SerializedObject {

            guard let data = data else { throw ResponseSerializerError.noData }

            do {
                return try jsonDecoder.decode(SerializedObject.self, from: data)
            }
            catch let serializedObjectError {
                throw (try? jsonDecoder.decode(SerializedErrorObject.self, from: data)) ?? serializedObjectError
            }
        }

        public enum ResponseSerializerError: Error {
            case noData
        }
    }

    public class HttpStatusCodeResponseSerializer: NetworkingResponseSerializer {
        public typealias SerializedObject = Int

        public init() {}

        public func serialize(request: URLRequest?, response: HTTPURLResponse?, data: Data?, error: Error?) throws -> SerializedObject {
            guard let response = response else { throw ResponseSerializerError.httpResponseCodeMissing }
            return response.statusCode
        }

        public enum ResponseSerializerError: Error {
            case httpResponseCodeMissing
        }
    }

    public class DataResponseSerializer: NetworkingResponseSerializer {
        public typealias SerializedObject = Data

        public init() {}

        public func serialize(request: URLRequest?, response: HTTPURLResponse?, data: Data?, error: Error?) throws -> SerializedObject {
            guard let data = data else { throw ResponseSerializerError.noData }
            return data
        }

        public enum ResponseSerializerError: Error {
            case noData
        }
    }
}
