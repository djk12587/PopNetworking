//
//  File.swift
//  
//
//  Created by Dan Koza on 4/14/21.
//

import Foundation

public protocol Mappable {
    associatedtype SourceModel
    init(sourceModel: SourceModel)
}

extension Array: Mappable where Element: Mappable {

    public typealias SourceModel = [Element.SourceModel]

    public init(sourceModel: [Element.SourceModel]) {
        self = sourceModel.compactMap { Element(sourceModel: $0) }
    }
}

extension NetworkingResponseSerializers {
    ///Attempts to parse response `Data` into a `SourceModel`, then convert that  `SourceModel` into a  `ResponseModel`. This provides a layer of abstraction between a `ResponseModel` and `SourceModel`.
    public class DecodableMappableResponse<ResponseModel: Mappable,
                                           ResponseError: Mappable & Error,
                                           SourceModel: Decodable,
                                           SourceError: Decodable & Error>: NetworkingResponseSerializer
                                           where SourceModel == ResponseModel.SourceModel,
                                                 SourceError == ResponseError.SourceModel {

        public typealias SerializedObject = ResponseModel
        public typealias SerializedErrorObject = ResponseError

        private let jsonDecoder: JSONDecoder

        public init(jsonDecoder: JSONDecoder = JSONDecoder()) {
            self.jsonDecoder = jsonDecoder
        }

        public func serialize(request: URLRequest?, response: HTTPURLResponse?, data: Data?, error: Error?) -> Result<SerializedObject, Error> {

            if let error = error { return .failure(error) }
            guard let data = data else { return .failure(ResponseSerializerError.noData) }

            do {
                let sourceModel = try jsonDecoder.decode(SourceModel.self, from: data)
                return .success(SerializedObject(sourceModel: sourceModel))
            }
            catch let serializedObjectError {
                if let sourceError = try? jsonDecoder.decode(SourceError.self, from: data) {
                    return .failure(ResponseError(sourceModel: sourceError))
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
}