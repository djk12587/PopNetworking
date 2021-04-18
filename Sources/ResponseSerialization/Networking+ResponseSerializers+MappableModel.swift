//
//  File.swift
//  
//
//  Created by Dan Koza on 4/14/21.
//

import Foundation

public protocol MappableModel {
    associatedtype SourceModel
    init(sourceModel: SourceModel) throws
}

extension Array: MappableModel where Element: MappableModel {

    public typealias SourceModel = [Element.SourceModel]

    public init(sourceModel: [Element.SourceModel]) throws {
        self = try sourceModel.compactMap { try Element(sourceModel: $0) }
    }
}

extension NetworkingResponseSerializers {
    ///Attempts to parse response `Data` into a `SourceModel`, then convert that  `SourceModel` into a  `ResponseModel`. This provides a layer of abstraction between a `ResponseModel` and `SourceModel`.
    public struct MappableModelResponse<ResponseModel: MappableModel,
                                        SourceModel: Decodable>: NetworkingResponseSerializer
    where SourceModel == ResponseModel.SourceModel {

        public typealias SerializedObject = ResponseModel

        private let jsonDecoder: JSONDecoder
        private let mockedResult: Result<SerializedObject, Error>?

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
                let sourceModel = try jsonDecoder.decode(SourceModel.self, from: data)
                let mappableModel = try SerializedObject(sourceModel: sourceModel)
                return .success(mappableModel)
            }
            catch let modelSerializationError {
                return .failure(modelSerializationError)
            }
        }

        public enum ResponseSerializerError: Error {
            case noData
            case errors([Error])
        }
    }

    ///Attempts to parse response `Data` into a `SourceModel` or a `SourceError`, then convert that  `SourceModel` or `SourceError` into a  `ResponseModel` or `ResponseError`. This provides a layer of abstraction between a `ResponseModel` and `SourceModel`.
    public struct MappableModelWithErrorResponse<ResponseModel: MappableModel,
                                                 ResponseError: MappableModel & Error,
                                                 SourceModel: Decodable,
                                                 SourceError: Decodable & Error>: NetworkingResponseSerializer
                                                 where SourceModel == ResponseModel.SourceModel,
                                                       SourceError == ResponseError.SourceModel {

        public typealias SerializedObject = ResponseModel
        public typealias SerializedErrorObject = ResponseError

        private let jsonDecoder: JSONDecoder
        private let mockedResult: Result<SerializedObject, Error>?

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
                let sourceModel = try jsonDecoder.decode(SourceModel.self, from: data)
                let mappableModel = try SerializedObject(sourceModel: sourceModel)
                return .success(mappableModel)
            }
            catch let modelSerializationError {
                do {
                    let sourceError = try jsonDecoder.decode(SourceError.self, from: data)
                    let mappableError = try ResponseError(sourceModel: sourceError)
                    return .failure(mappableError)
                }
                catch let errorSerializerError {
                    return .failure(ResponseSerializerError.errors([errorSerializerError,
                                                                    modelSerializationError]))
                }
            }
        }

        public enum ResponseSerializerError: Error {
            case noData
            case errors([Error])
        }
    }
}
