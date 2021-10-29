//
//  File.swift
//  
//
//  Created by Dan_Koza on 10/28/21.
//

import Foundation

@available(macOS 10.15, iOS 13, watchOS 6, tvOS 13, *)
public extension NetworkingRoute {
    var asyncTask: Task<ResponseSerializer.SerializedObject, Error> {
        return Task<ResponseSerializer.SerializedObject, Error> {
            return try await withCheckedThrowingContinuation { continuation in
                let cancellableRoute = request(runCompletionHandlerOn: DispatchQueue(label: UUID().uuidString)) { result in
                    continuation.resume(with: result)
                }
                do {
                    try Task.checkCancellation()
                }
                catch {
                    cancellableRoute.cancel()
                }
            }
        }
    }
}
