//
//  File.swift
//  
//
//  Created by Dan_Koza on 10/10/21.
//

import XCTest
@testable import PopNetworking

final class ReauthenticationTests: XCTestCase {

    func testReauthenticationSuccess() async {

        let mockTokenVerifier = Mock.TokenVerifier(route: Mock.Route(responseSerializer: Mock.ResponseSerializer(.success(()))))
        XCTAssertFalse(mockTokenVerifier.accessTokenIsValid)

        let reauthenticationHandler = ReauthenticationHandler(accessTokenVerifier: mockTokenVerifier)
        _ = await Mock.Route(session: NetworkingSession(urlSession: Mock.UrlSession(),
                                                        requestAdapter: reauthenticationHandler,
                                                        requestRetrier: reauthenticationHandler),
                             responseSerializer: Mock.ResponseSerializer<Void>()).result

        XCTAssertTrue(mockTokenVerifier.reauthorizationResult?.isSuccess == true)
        XCTAssertTrue(mockTokenVerifier.accessTokenIsValid)
    }

    func testReauthenticationFailure() async {

        let mockTokenVerifier = Mock.TokenVerifier(route: Mock.Route(responseSerializer: Mock.ResponseSerializer<Void>(.failure(NSError(domain: "force authorization failure", code: 0)))))
        XCTAssertFalse(mockTokenVerifier.accessTokenIsValid)

        let reauthenticationHandler = ReauthenticationHandler(accessTokenVerifier: mockTokenVerifier)
        let reauthResult = await Mock.Route(session: NetworkingSession(urlSession: Mock.UrlSession(),
                                                                       requestAdapter: reauthenticationHandler,
                                                                       requestRetrier: reauthenticationHandler),
                                            responseSerializer: Mock.ResponseSerializer<Void>()).result
        XCTAssertThrowsError(try reauthResult.get()) { error in
            XCTAssertEqual(error as? Mock.TokenVerifier.AccessTokenError, .tokenIsMissing)
        }
        XCTAssertTrue(mockTokenVerifier.reauthorizationResult?.isFailure == true)
        XCTAssertFalse(mockTokenVerifier.accessTokenIsValid)
    }

    func testCancelingReauthenticationRequest() async {

        let mockTokenVerifier = Mock.TokenVerifier(route: Mock.Route(responseSerializer: Mock.ResponseSerializer(.success(()))))
        XCTAssertFalse(mockTokenVerifier.accessTokenIsValid)

        let reauthenticationHandler = ReauthenticationHandler(accessTokenVerifier: mockTokenVerifier)
        let reauthRequestTask = Mock.Route(session: NetworkingSession(requestAdapter: reauthenticationHandler,
                                                                      requestRetrier: reauthenticationHandler),
                                           responseSerializer: Mock.ResponseSerializer<Void>()).task()
        reauthRequestTask.cancel()
        let reauthResult = await reauthRequestTask.result

        XCTAssertThrowsError(try reauthResult.get()) { error in
            XCTAssertEqual(URLError.cancelled.rawValue, (error as NSError).code)
        }
    }

    func testMultipleUnauthorizedRoutesPerformsReauthenticationOnlyOnce() async throws {

        let mockTokenVerifier = Mock.TokenVerifier(route: Mock.Route(responseSerializer: Mock.ResponseSerializer(.success(()))))
        XCTAssertEqual(mockTokenVerifier.reauthorizationCount, 0)
        XCTAssertFalse(mockTokenVerifier.accessTokenIsValid)

        let reauthenticationHandler = ReauthenticationHandler(accessTokenVerifier: mockTokenVerifier)
        let session = NetworkingSession(urlSession: Mock.UrlSession(),
                                        requestAdapter: reauthenticationHandler,
                                        requestRetrier: reauthenticationHandler)
        _ = await Mock.Route(session: session, responseSerializer: Mock.ResponseSerializer<Void>()).result
        _ = await Mock.Route(session: session, responseSerializer: Mock.ResponseSerializer<Void>()).result

        XCTAssertEqual(mockTokenVerifier.reauthorizationCount, 1)
        XCTAssertTrue(mockTokenVerifier.accessTokenIsValid)
    }
}

private extension Mock {
    class TokenVerifier: AccessTokenVerification {

        enum AccessTokenError: Error {
            case tokenIsMissing
        }

        private(set) var accessToken: String = ""
        private let maxNumberOfRetries: Int
        private(set) var retryCount = 0
        private(set) var reauthorizationResult: Result<ReauthenticationRoute.ResponseSerializer.SerializedObject, Error>?
        private(set) var reauthorizationCount = 0

        let reauthenticationRoute: Mock.Route<Mock.ResponseSerializer<Void>>
        var accessTokenIsValid: Bool { !accessToken.isEmpty }

        init(route: Mock.Route<Mock.ResponseSerializer<Void>>,
             numberOfRetries: Int = 1) {
            reauthenticationRoute = route
            self.maxNumberOfRetries = numberOfRetries - 1
        }

        func isAuthorizationRequired(for urlRequest: URLRequest) -> Bool {
            return true
        }

        func validateAccessToken() throws {
            guard accessToken.isEmpty else { return }
            throw AccessTokenError.tokenIsMissing
        }

        func isAuthorizationValid(for urlRequest: URLRequest) -> Bool {
            urlRequest.allHTTPHeaderFields?["Authorization"] == "Bearer \(accessToken)"
        }

        func setAuthorization(for urlRequest: inout URLRequest) throws {
            urlRequest.allHTTPHeaderFields?["Authorization"] = accessToken
        }

        func determineReauthorizationMethod(urlRequest: URLRequest?, dueTo error: Error, urlResponse: HTTPURLResponse?, retryCount: Int) -> ReauthorizationMethod {
            guard retryCount <= maxNumberOfRetries && ((error as? AccessTokenError) == .tokenIsMissing || urlResponse?.statusCode == 401) else { return .doNothing }
            self.retryCount += 1
            return .refreshAuthorization
        }

        func saveReauthentication(result: Result<Void, Error>) async -> Bool {
            reauthorizationResult = result
            reauthorizationCount += 1
            switch result {
                case .success:
                    let randomMockToken = String(Int.random(in: 0...Int.max))
                    accessToken = randomMockToken
                case .failure:
                    accessToken = ""
            }
            return true
        }
    }
}

private extension Result {
    var isSuccess: Bool {
        guard case .success = self else { return false }
        return true
    }

    var isFailure: Bool {
        guard case .failure = self else { return false }
        return true
    }
}
