//
//  NetworkingRouteHttpMethod.swift
//
//  Created by Dan_Koza on 10/4/21.
//

import Foundation

public enum NetworkingRouteHttpMethod: String, Sendable {
    case get = "GET"
    case head = "HEAD"
    case options = "OPTIONS"
    case post = "POST"
    case delete = "DELETE"
    case put = "PUT"
    case patch = "PATCH"
}
