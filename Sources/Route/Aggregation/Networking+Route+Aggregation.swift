//
//  File.swift
//  
//
//  Created by Dan_Koza on 5/26/21.
//

import Foundation

extension NetworkingRoute {

    @discardableResult
    public func and<ExtraRoute: NetworkingRoute>(run route: ExtraRoute,
                                                 executeCompletionHandlerOn queue: DispatchQueue = .main,
                                                 completion: @escaping (Result<(Self.ResponseSerializer.SerializedObject,
                                                                                ExtraRoute.ResponseSerializer.SerializedObject), Error>) -> Void) -> Cancellable {
        let operationQueue = OperationQueue()
        let groupedTasks = DispatchGroup()
        groupedTasks.enter()
        groupedTasks.enter()

        var firstRouteResult: Result<Self.ResponseSerializer.SerializedObject, Error> = .failure(NetworkingRouteError.AggregatedRoutes.routeNeverFinished)
        let firstOperation = NetworkingRouteOperation(run: self) { result in
            firstRouteResult = result
            groupedTasks.leave()
        }

        var secondRouteResult: Result<ExtraRoute.ResponseSerializer.SerializedObject, Error> = .failure(NetworkingRouteError.AggregatedRoutes.routeNeverFinished)
        let secondOperation = NetworkingRouteOperation(run: route) { result in
            secondRouteResult = result
            groupedTasks.leave()
        }

        operationQueue.addOperation(firstOperation)
        operationQueue.addOperation(secondOperation)

        groupedTasks.notify(queue: queue) {
            switch (firstRouteResult, secondRouteResult) {
                case (.success(let firstRouteResponseModel), .success(let secondRouteResponseModel)):
                    completion(.success((firstRouteResponseModel, secondRouteResponseModel)))

                case (.failure(let firstRouteError), .failure(let secondRouteError)):
                    completion(.failure(NetworkingRouteError.AggregatedRoutes.multiFailure([firstRouteError, secondRouteError])))

                case (.failure(let firstRouteError), _):
                    completion(.failure(firstRouteError))

                case (_, .failure(let secondRouteError)):
                    completion(.failure(secondRouteError))
            }
        }

        return CancellableQueue(queue: operationQueue)
    }
}
