//
//  File.swift
//  
//
//  Created by Dan_Koza on 11/11/21.
//

import Foundation

public protocol URLSessionProtocol {
    func dataTask(with request: URLRequest, completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void) -> URLSessionDataTask
}

extension URLSession: URLSessionProtocol {}
