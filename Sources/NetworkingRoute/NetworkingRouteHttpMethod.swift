//
//  NetworkingRouteHttpMethod.swift
//
//  Created by Dan_Koza on 10/4/21.
//

import Foundation

public enum NetworkingRouteHttpMethod: String, Sendable {
    case get = "GET"
    case post = "POST"
    case delete = "DELETE"
    case put = "PUT"
    case patch = "PATCH"
}
