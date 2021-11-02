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

        let mockTokenVerifier = MockTokenVerifier(route: MockAuthRoute(mockResponse: .success(200)))
        XCTAssertFalse(mockTokenVerifier.accessTokenIsValid)

        let session = NetworkingSession(accessTokenVerifier: mockTokenVerifier)
        _ = await session.execute(route: UnauthenticatedRoute()).result

        XCTAssertTrue(mockTokenVerifier.reauthorizationResult?.isSuccess == true)
        XCTAssertTrue(mockTokenVerifier.accessTokenIsValid)
    }

    func testReauthenticationFailure() async {

        let mockTokenVerifier = MockTokenVerifier(route: MockAuthRoute(mockResponse: .failure(NSError(domain: "force authorization failure", code: 0))))
        XCTAssertFalse(mockTokenVerifier.accessTokenIsValid)

        let session = NetworkingSession(accessTokenVerifier: mockTokenVerifier)
        let result = await session.execute(route: UnauthenticatedRoute()).result
        switch result {
            case .success:
                XCTFail("This request is supposed to fail")
            case .failure(let error):
                XCTAssertEqual(error as? MockTokenVerifier.AccessTokenError, .tokenIsInvalid)
        }

        XCTAssertTrue(mockTokenVerifier.reauthorizationResult?.isFailure == true)
        XCTAssertFalse(mockTokenVerifier.accessTokenIsValid)
    }

    func testCancellingReauthenticationRequest() async {

        let mockTokenVerifier = MockTokenVerifier(route: MockAuthRoute(mockResponse: .success(200)))
        XCTAssertFalse(mockTokenVerifier.accessTokenIsValid)

        let session = NetworkingSession(accessTokenVerifier: mockTokenVerifier)
        let reauthRequestTask = session.execute(route: UnauthenticatedRoute())
        reauthRequestTask.cancel()
        switch await reauthRequestTask.result {
            case .success:
                XCTFail("this request is supposed to fail due to being cancelled")
            case .failure(let error):
                XCTAssertEqual(NSURLErrorCancelled, (error as NSError).code)
        }
    }

    func testMultipleUnauthorizedRoutesPerformsReauthenticationOnlyOnce() async throws {

        let mockTokenVerifier = MockTokenVerifier(route: MockAuthRoute(mockResponse: .success(200)))
        XCTAssertEqual(mockTokenVerifier.reauthorizationCount, 0)
        XCTAssertFalse(mockTokenVerifier.accessTokenIsValid)

        let session = NetworkingSession(accessTokenVerifier: mockTokenVerifier)
        _ = await session.execute(route: UnauthenticatedRoute()).result
        _ = await session.execute(route: UnauthenticatedRoute()).result

        XCTAssertEqual(mockTokenVerifier.reauthorizationCount, 1)
        XCTAssertTrue(mockTokenVerifier.accessTokenIsValid)
    }
}

private extension ReauthenticationTests {

    struct MockAuthRoute: NetworkingRoute {
        let baseUrl: String = ""
        let path: String = ""
        let method: NetworkingRouteHttpMethod = .post
        let parameterEncoding: NetworkingRequestParameterEncoding = .url(params: nil)
        let responseSerializer = NetworkingResponseSerializers.HttpStatusCodeResponseSerializer()
        let mockResponse: Result<Int, Error>?
    }

    struct UnauthenticatedRoute: NetworkingRoute {
        let baseUrl: String = "https://google.com"
        let path: String = ""
        let method: NetworkingRouteHttpMethod = .post
        let parameterEncoding: NetworkingRequestParameterEncoding = .url(params: nil)
        let headers: NetworkingRouteHttpHeaders? = ["Authorization" : ""]
        let responseSerializer = NetworkingResponseSerializers.HttpStatusCodeResponseSerializer()
    }

    class MockTokenVerifier: AccessTokenVerification {

        enum AccessTokenError: Error {
            case tokenIsInvalid
        }

        private(set) var accessToken: String = ""
        private let maxNumberOfRetries: Int
        private(set) var retryCount = 0
        private(set) var reauthorizationResult: Result<ReauthenticationRoute.ResponseSerializer.SerializedObject, Error>?
        private(set) var reauthorizationCount = 0

        let reauthenticationRoute: ReauthenticationTests.MockAuthRoute
        var accessTokenIsValid: Bool { !accessToken.isEmpty }

        init(route: ReauthenticationTests.MockAuthRoute,
             numberOfRetries: Int = 1) {
            reauthenticationRoute = route
            self.maxNumberOfRetries = numberOfRetries - 1
        }

        func isAuthorizationRequired(for urlRequest: URLRequest) -> Bool {
            return true
        }

        func validateAccessToken() throws {
            guard accessToken.isEmpty else { return }
            throw AccessTokenError.tokenIsInvalid
        }

        func isAuthorizationValid(for urlRequest: URLRequest) -> Bool {
            urlRequest.allHTTPHeaderFields?["Authorization"] == "Bearer \(accessToken)"
        }

        func setAuthorization(for urlRequest: inout URLRequest) throws {
            urlRequest.allHTTPHeaderFields?["Authorization"] = accessToken
        }

        func shouldReauthenticate(urlRequest: URLRequest?, dueTo error: Error, urlResponse: HTTPURLResponse?, retryCount: Int) -> Bool {
            guard retryCount <= maxNumberOfRetries && ((error as? AccessTokenError) == .tokenIsInvalid || urlResponse?.statusCode == 401) else { return false }
            self.retryCount += 1
            return true
        }

        func saveReauthentication(result: Result<Int, Error>) async -> Bool {
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