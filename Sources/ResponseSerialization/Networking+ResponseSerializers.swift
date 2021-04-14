//
//  Networking+ResponseSerializers.swift
//  PopNetworking
//
//  Created by Daniel Koza on 1/9/21.
//  Copyright © 2021 Daniel Koza. All rights reserved.
//

import Foundation

public protocol ViewModel {
    init<ApiModel: Decodable>(apiModel: ApiModel)
}

public enum NetworkingResponseSerializers {

    ///Attempts to parse response `Data` into a `ApiModelType`, then convert that  `ApiModelType` into a  `ViewModelType`. This provides a layer of abstraction between a `ViewModelType` and `ApiModelType`.
    public class ViewModelDecodableResponse<ViewModelType: ViewModel,
                                            ViewModelErrorType: ViewModel & Error,
                                            ApiModelType: Decodable,
                                            ApiErrorType: Decodable & Error>: NetworkingResponseSerializer {

        public typealias SerializedObject = ViewModelType
        public typealias SerializedErrorObject = ViewModelErrorType

        private let jsonDecoder: JSONDecoder

        public init(jsonDecoder: JSONDecoder = JSONDecoder()) {
            self.jsonDecoder = jsonDecoder
        }

        public func serialize(request: URLRequest?, response: HTTPURLResponse?, data: Data?, error: Error?) -> Result<SerializedObject, Error> {

            if let error = error { return .failure(error) }
            guard let data = data else { return .failure(ResponseSerializerError.noData) }

            do {
                let apiModel = try jsonDecoder.decode(ApiModelType.self, from: data)
                return .success(SerializedObject(apiModel: apiModel))
            }
            catch let serializedObjectError {
                if let apiError = try? jsonDecoder.decode(ApiErrorType.self, from: data) {
                    return .failure(ViewModelErrorType(apiModel: apiError))
                }
                else {
                    return .failure(serializedObjectError)
                }
            }
        }

        public enum ResponseSerializerError: Error {
            case noData
        }
    }

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
                return .failure((try? jsonDecoder.decode(SerializedErrorObject.self, from: data)) ?? serializedObjectError)
            }
        }

        public enum ResponseSerializerError: Error {
            case noData
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
