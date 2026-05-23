//
//  Response+DecodableAndError.swift
//  PopNetworking
//

import Foundation

public extension NetworkingSerializers.Response {

    /// Parses response `Data` into the generic `SuccessType`, falling back to parsing the
    /// same `Data` as `FailureType` on a failed success-decode. `FailureType` must conform
    /// to both `Decodable` and `Error` so it can surface as a typed API error.
    struct DecodableAndError<SuccessType: Swift.Decodable & Sendable,
                             FailureType: Swift.Decodable & Error>: NetworkingResponseSerializer {

        public typealias SerializedObject = SuccessType
        public typealias SerializedErrorObject = FailureType

        /// Thrown when the response `Data` decodes as neither `SuccessType` nor `FailureType`.
        public struct SerializationError: Error {
            public let successTypeDecodingError: Error
            public let failureTypeDecodingError: Error

            public init(successTypeDecodingError: Error, failureTypeDecodingError: Error) {
                self.successTypeDecodingError = successTypeDecodingError
                self.failureTypeDecodingError = failureTypeDecodingError
            }
        }

        private let successTypeJsonDecoder: JSONDecoder
        private let failureTypeJsonDecoder: JSONDecoder

        public init(jsonDecoder: JSONDecoder = JSONDecoder()) {
            self.successTypeJsonDecoder = jsonDecoder
            self.failureTypeJsonDecoder = jsonDecoder
        }

        public init(successTypeJsonDecoder: JSONDecoder = JSONDecoder(),
                    failureTypeJsonDecoder: JSONDecoder = JSONDecoder()) {
            self.successTypeJsonDecoder = successTypeJsonDecoder
            self.failureTypeJsonDecoder = failureTypeJsonDecoder
        }

        public func serialize(responseResult: Result<(Foundation.Data, URLResponse), Error>) async -> Result<SuccessType, Error> {
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
}
