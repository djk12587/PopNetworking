//
//  File.swift
//  
//
//  Created by Dan_Koza on 5/26/21.
//

import Foundation

public class CancellableTasks: Cancellable {

    private var cancellablesTasks: [Cancellable]

    internal init(cancellablesTasks: [Cancellable] = []) {
        self.cancellablesTasks = cancellablesTasks
    }

    internal func append(cancellablesTask: Cancellable?) {
        guard let cancellablesTask = cancellablesTask else { return }
        cancellablesTasks.append(cancellablesTask)
    }

    public func cancel() {
        cancellablesTasks.forEach { $0.cancel() }
    }
}
