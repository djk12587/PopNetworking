//
//  File.swift
//  
//
//  Created by Dan_Koza on 5/26/21.
//

import Foundation

internal class NetworkingRouteOperation<Route: NetworkingRoute>: AsyncOperation {

    struct RouteOperationError: Error {
        let route: Route
        let failureReason: String
        let code: Int
    }

    private let route: Route
    private(set) var urlSessionTask: URLSessionTask?
    private var completion: ((Result<Route.ResponseSerializer.SerializedObject, Error>) -> Void)?

    init(run: Route, completion: (Result<Route.ResponseSerializer.SerializedObject, Error>) -> Void) {
        self.route = run
        super.init()
    }

    override func cancel() {
        super.cancel()
        urlSessionTask?.cancel()
        state = .finished
        executeCompletionBlock(with: .failure(RouteOperationError(route: route, failureReason: "The request was cancelled", code: NSURLErrorCancelled)))
    }

    override func start() {
        super.start()
        guard !isCancelled else {
            state = .finished
            executeCompletionBlock(with: .failure(RouteOperationError(route: route, failureReason: "The request was cancelled", code: NSURLErrorCancelled)))
            return
        }
    }

    override func main() {
        super.main()
        guard !isCancelled else {
            state = .finished
            executeCompletionBlock(with: .failure(RouteOperationError(route: route, failureReason: "The request was cancelled", code: NSURLErrorCancelled)))
            return
        }

        urlSessionTask = route.request() { [weak self] result in
            guard let self = self else { return }
            self.executeCompletionBlock(with: result)
            self.state = .finished
        }
    }

    private func executeCompletionBlock(with result: Result<Route.ResponseSerializer.SerializedObject, Error>) {
        completion?(result)
        completion = nil
    }
}

internal class AsyncOperation: Operation {

    override var isAsynchronous: Bool { return true }
    override var isExecuting: Bool { return state == .executing }
    override var isFinished: Bool { return state == .finished }

    var state = State.ready {
        willSet {
            willChangeValue(forKey: state.keyPath)
            willChangeValue(forKey: newValue.keyPath)
        }
        didSet {
            didChangeValue(forKey: state.keyPath)
            didChangeValue(forKey: oldValue.keyPath)
        }
    }

    enum State: String {
        case ready = "Ready"
        case executing = "Executing"
        case finished = "Finished"
        fileprivate var keyPath: String { return "is" + self.rawValue }
    }

    override func start() {
        guard !isCancelled else { state = .finished; return }
        state = .ready
        main()
    }

    override func main() {
        state = isCancelled ? .finished : .executing
    }
}
