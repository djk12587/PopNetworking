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

        public func serialize(request: URLRequest?, response: HTTPURLResponse?, data: Data?, error: Error?) -> Result<SerializedObject, Error> {

            if let error = error { return .failure(error) }
            guard let data = data else { return .failure(ResponseSerializerError.noData) }

            do {
                let serializedOjbect = try jsonDecoder.decode(SerializedObject.self, from: data)
                return .success(serializedOjbect)
            }
            catch let serializedObjectError {
                return .failure((try? jsonDecoder.decode(SerializedErrorObject.self, from: data)) ?? serializedObjectError)
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
