//
//  File.swift
//  
//
//  Created by Dan_Koza on 10/21/21.
//

import Foundation

public protocol AccessTokenVerification: AnyObject {
    associatedtype ReauthenticationRoute: NetworkingRoute
    var reauthenticationRoute: ReauthenticationRoute { get }

    func validateAccessToken() throws
    func isAuthorizationRequired(for urlRequest: URLRequest) -> Bool
    func isAuthorizationValid(for urlRequest: URLRequest) -> Bool
    func setAuthorization(for urlRequest: inout URLRequest) throws

    func shouldReauthenticate(urlRequest: URLRequest, dueTo error: Error, urlResponse: HTTPURLResponse, retryCount: Int) -> Bool
    func reauthenticationCompleted(result: Result<ReauthenticationRoute.ResponseSerializer.SerializedObject, Error>,
                                   finishedProcessingResult: @escaping () -> Void)
}
