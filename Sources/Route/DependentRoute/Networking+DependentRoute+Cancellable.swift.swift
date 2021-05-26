//
//  File.swift
//  
//
//  Created by Dan_Koza on 5/26/21.
//

import Foundation

public class CancellableUrlSessionTasks: Cancellable {
    private var urlSessionTasks: [URLSessionTask]

    internal init(urlSessionTasks: [URLSessionTask] = []) {
        self.urlSessionTasks = urlSessionTasks
    }

    internal func append (urlSessionTask: URLSessionTask?) {
        guard let urlSessionTask = urlSessionTask else { return }
        urlSessionTasks.append(urlSessionTask)
    }

    public func cancel() {
        urlSessionTasks.forEach { $0.cancel() }
    }
}
