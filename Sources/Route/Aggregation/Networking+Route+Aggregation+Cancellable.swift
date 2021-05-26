//
//  File.swift
//  
//
//  Created by Dan_Koza on 5/26/21.
//

import Foundation

public protocol Cancellable {
    func cancel()
}

public class CancellableQueue: Cancellable {
    private let queue: OperationQueue

    internal init(queue: OperationQueue) {
        self.queue = queue
    }

    public func cancel() {
        queue.cancelAllOperations()
    }
}
