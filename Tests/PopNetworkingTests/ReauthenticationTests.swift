//
//  File.swift
//  
//
//  Created by Dan_Koza on 10/10/21.
//

import XCTest
@testable import PopNetworking

final class ReauthenticationTests: XCTestCase {
    func testReauthenticationSuccess() throws {

        let mockTokenVerifier = MockTokenVerifier(route: MockAuthRoute(mockResponse: .success(200)))
        XCTAssertTrue(mockTokenVerifier.tokenIsExpired)

        let session = NetworkingSession(accessTokenVerifier: mockTokenVerifier)
        let unauthenticatedRouteWillFinish = expectation(description: "unauthenticatedRouteWillFinish")
        _ = session.execute(route: UnauthenticatedRoute()) { _ in
            unauthenticatedRouteWillFinish.fulfill()
        }
        waitForExpectations(timeout: 5)

        XCTAssertFalse(mockTokenVerifier.tokenIsExpired)
    }

    func testReauthenticationFailure() throws {

        let mockTokenVerifier = MockTokenVerifier(route: MockAuthRoute(mockResponse: .failure(NSError(domain: "force authorization failure", code: 0))))
        XCTAssertTrue(mockTokenVerifier.tokenIsExpired)

        let session = NetworkingSession(accessTokenVerifier: mockTokenVerifier)
        let unauthenticatedRouteWillFinish = expectation(description: "unauthenticatedRouteWillFinish")
        _ = session.execute(route: UnauthenticatedRoute()) { result in
            switch result {
                case .success:
                    XCTFail("This request is supposed to fail")
                case .failure(let error):
                    XCTAssertEqual(error as? ReauthenticationHandlerError, ReauthenticationHandlerError.tokenIsInvalid)
            }
            unauthenticatedRouteWillFinish.fulfill()
        }
        waitForExpectations(timeout: 5)

        XCTAssertTrue(mockTokenVerifier.tokenIsExpired)
    }

    func testReauthenticationRetryMultipleTimes() throws {

        let mockTokenVerifier = MockTokenVerifier(route: MockAuthRoute(mockResponse: .success(200)), numberOfRetries: 3)
        XCTAssertEqual(mockTokenVerifier.retryCount, 0)

        let session = NetworkingSession(accessTokenVerifier: mockTokenVerifier)
        let unauthenticatedRouteWillFinish = expectation(description: "unauthenticatedRouteWillFinish")
        _ = session.execute(route: UnauthenticatedRoute()) { result in
            if case .success = result {
                XCTFail("This request is supposed to fail")
            }
            unauthenticatedRouteWillFinish.fulfill()
        }
        waitForExpectations(timeout: 5)
        XCTAssertEqual(mockTokenVerifier.retryCount, 3)
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
        let baseUrl: String = "https://mockBaseurl.com"
        let path: String = "/mockPath"
        let method: NetworkingRouteHttpMethod = .post
        let parameterEncoding: NetworkingRequestParameterEncoding = .url(params: nil)
        let headers: NetworkingRouteHttpHeaders? = ["Authorization" : ""]
        let responseSerializer = NetworkingResponseSerializers.HttpStatusCodeResponseSerializer()
    }

    class MockTokenVerifier: AccessTokenVerification {
        let reauthenticationRoute: ReauthenticationTests.MockAuthRoute
        var accessToken: String = ""
        var tokenIsExpired: Bool { accessToken.isEmpty }

        private let numberOfRetries: Int
        private(set) var retryCount = 0

        init (route: ReauthenticationTests.MockAuthRoute, numberOfRetries: Int = 1) {
            reauthenticationRoute = route
            self.numberOfRetries = numberOfRetries
        }

        func extractAuthorizationKey(from urlRequest: URLRequest) -> String? {
            return "Authorization"
        }

        func shouldRetry(urlRequest: URLRequest, dueTo error: Error, urlResponse: HTTPURLResponse, retryCount: Int) -> Bool {
            self.retryCount = retryCount
            return retryCount < numberOfRetries
        }

        func reauthenticationCompleted(result: Result<Int, Error>, finishedUpdatingLocalAuthorization: @escaping () -> Void) {
            accessToken = (try? result.get()) == 200 ? "newToken" : ""
            finishedUpdatingLocalAuthorization()
        }
    }
}
