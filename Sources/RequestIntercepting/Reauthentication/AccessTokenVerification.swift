//
//  File.swift
//  
//
//  Created by Dan_Koza on 10/21/21.
//

import Foundation

/**
 A protocol that helps ensure a `URLRequest`'s authorization is always up to date. ``AccessTokenVerification`` can be applied to a ``NetworkingSession`` via ``NetworkingSession/init(session:accessTokenVerifier:)``

 - Attention: You are responsible for supplying and saving your own access token.
 */
public protocol AccessTokenVerification: AnyObject {
    /// This type should be the route/endpoint your personal server exposes to reauthenticate an expired access token
    associatedtype ReauthenticationRoute: NetworkingRoute
    /// The ``NetworkingRoute`` that will be used to refresh your authorization to your server. This ``NetworkingRoute`` should return an object that contains new authorization data for your server
    ///
    /// If ``shouldReauthenticate(urlRequest:dueTo:urlResponse:retryCount:)`` returns `false`, ``reauthenticationRoute-swift.property`` will be executed, and ``saveReauthentication(result:)`` will provide the result.
    var reauthenticationRoute: ReauthenticationRoute { get }

    /// Before a `URLRequest` is sent this function allows you to check the validity of your access token.
    ///
    /// Do nothing if your access token is valid
    ///
    /// - Throws: If your access token is expired, throw an `Error`. Throwing an error will trigger ``shouldReauthenticate(urlRequest:dueTo:urlResponse:retryCount:)`` with the error you threw.
    func validateAccessToken() throws

    /// Before a `URLRequest` is sent, this function asks if the request requires authentication
    ///
    /// - Parameters:
    ///     - urlRequest: The `URLRequest` that will be sent over the wire
    ///
    /// - Returns: A `Bool` indicating if the supplied `URLRequest` requires authentication
    ///
    /// If `false` is returned, ``isAuthorizationValid(for:)`` && ``setAuthorization(for:)`` will be skipped and the `URLRequest` will be sent
    func isAuthorizationRequired(for urlRequest: URLRequest) -> Bool

    /// Before a `URLRequest` is sent, this function asks if the `URLRequest`'s authentication is valid.
    ///
    /// - Parameters:
    ///     - urlRequest: The `URLRequest` that will be sent over the wire
    ///
    /// If `false` is returned, ``setAuthorization(for:)`` will be executed. If `true` is returned, the `URLRequest` will be sent.
    ///
    /// - Returns: A `Bool` indicating if the supplied `URLRequest` authorization is valid.
    func isAuthorizationValid(for urlRequest: URLRequest) -> Bool

    /// Before a `URLRequest` is sent, this function allows you to update the authorization of the `URLRequest`
    ///
    /// - Parameters:
    ///     - urlRequest: The `URLRequest` that will be sent over the wire
    ///
    /// An error can be thrown incase there was a problem updating the authorization
    func setAuthorization(for urlRequest: inout URLRequest) throws

    /// Your `URLRequest` has failed. Return a `Bool` incase the `URLRequest` should be retried or not.
    ///
    /// - Parameters:
    ///     - urlRequest: A`URLRequest` that failed
    ///     - error: The reason the `URLRequest` failed
    ///     - urlResponse: The `URLRequest`'s `HTTPURLResponse`
    ///     - retryCount: The number of times this particular `URLRequest` has been retried
    ///
    /// - Returns: A `Bool` indicating if the request requires reauthentication. If `true` the ``reauthenticationRoute-swift.property`` will be executed. Once the ``reauthenticationRoute-swift.property`` successfully finishes, the `URLRequest` will be retried.
    ///
    /// - Attention: If you never return `false` there is chance your `URLRequest` will attempt to retry in an infinite loop.
    func shouldReauthenticate(urlRequest: URLRequest?, dueTo error: Error, urlResponse: HTTPURLResponse?, retryCount: Int) -> Bool

    /// Informs you of the result of ``reauthenticationRoute-swift.property``. Use this function to save your updated authorization data.
    ///
    /// - Parameters:
    ///     - result: The result of ``reauthenticationRoute-swift.property``
    ///
    /// - Returns: A `Bool` indicating if saving your authorization data was successful or not. If saving your authorization data failed return `false`, and the request will not be retried.
    ///
    /// - Attention: It is best practice to save your newly aquired authorization data
    func saveReauthentication(result: Result<ReauthenticationRoute.ResponseSerializer.SerializedObject, Error>) async -> Bool
}
