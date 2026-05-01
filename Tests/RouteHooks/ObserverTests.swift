//
//  ObserverTests.swift
//  PopNetworkingTests
//

import XCTest
@testable import PopNetworking

class ObserverTests: XCTestCase {

    func testWillSendCapturesUrlRequestSentToUrlSession() async throws {
        let mockObserver = Mock.Observer()
        let mockUrlSession = Mock.UrlSession()
        _ = await Mock.Route(session: NetworkingSession(urlSession: mockUrlSession, observers: [mockObserver]),
                             responseSerializer: Mock.ResponseSerializer<Void>()).result

        let willSendDidRun = await mockObserver.willSendDidRun
        XCTAssertTrue(willSendDidRun)

        let captured = await mockObserver.capturedWillSendUrlRequest
        let lastRequest = await mockUrlSession.lastRequest
        XCTAssertNotNil(captured)
        XCTAssertEqual(captured?.url, lastRequest?.url,
            "Observer's willSend should receive the same URLRequest that URLSession.data(for:) was called with.")
    }

    func testWillSendSeesAdaptedRequest() async throws {
        let adaptedUrlRequest = URLRequest(url: URL(string: "https://adaptedRequest.com")!)
        let mockAdapter = Mock.Interceptor(adapterResult: .adapt(adaptedUrlRequest: adaptedUrlRequest),
                                           retrierResult: .doNotRetry)
        let mockObserver = Mock.Observer()

        _ = await Mock.Route(baseUrl: "https://originalRequest.com",
                             session: NetworkingSession(urlSession: Mock.UrlSession(), adapter: mockAdapter, observers: [mockObserver]),
                             responseSerializer: Mock.ResponseSerializer<Void>()).result

        let captured = await mockObserver.capturedWillSendUrlRequest
        XCTAssertEqual(captured?.url, adaptedUrlRequest.url)
    }

    func testDidReceiveFiresOnTransportSuccess() async throws {
        let expectedData = Data("hello".utf8)
        let expectedResponse = HTTPURLResponse(url: URL(string: "https://mockUrl.com")!,
                                               statusCode: 200,
                                               httpVersion: nil,
                                               headerFields: nil)!
        let mockObserver = Mock.Observer()
        let mockUrlSession = Mock.UrlSession(mockResult: .success(expectedData), mockUrlResponse: expectedResponse)

        _ = await Mock.Route(session: NetworkingSession(urlSession: mockUrlSession, observers: [mockObserver]),
                             responseSerializer: Mock.ResponseSerializer<Void>()).result

        let didReceiveDidRun = await mockObserver.didReceiveDidRun
        let didFailDidRun = await mockObserver.didFailDidRun
        XCTAssertTrue(didReceiveDidRun)
        XCTAssertFalse(didFailDidRun)

        let capturedData = await mockObserver.capturedDidReceiveData
        let capturedResponse = await mockObserver.capturedDidReceiveUrlResponse
        XCTAssertEqual(capturedData, expectedData)
        XCTAssertEqual((capturedResponse as? HTTPURLResponse)?.statusCode, 200)
    }

    func testDidFailFiresOnTransportError() async throws {
        let transportError = URLError(.timedOut)
        let mockObserver = Mock.Observer()
        let mockUrlSession = Mock.UrlSession(mockResult: .failure(transportError))

        _ = await Mock.Route(baseUrl: "https://failingHost.com",
                             session: NetworkingSession(urlSession: mockUrlSession, observers: [mockObserver]),
                             responseSerializer: Mock.ResponseSerializer<Void>()).result

        let didFailDidRun = await mockObserver.didFailDidRun
        let didReceiveDidRun = await mockObserver.didReceiveDidRun
        XCTAssertTrue(didFailDidRun)
        XCTAssertFalse(didReceiveDidRun)

        let capturedError = await mockObserver.capturedDidFailError
        XCTAssertEqual((capturedError as? URLError)?.code, .timedOut)

        let capturedUrlRequest = await mockObserver.capturedDidFailUrlRequest
        XCTAssertNotNil(capturedUrlRequest, "didFail should receive the URLRequest that was attempted.")
        XCTAssertEqual(capturedUrlRequest?.url?.host, "failingHost.com")
    }

    func testDidFailDoesNotFireOnValidatorFailure() async throws {
        let mockObserver = Mock.Observer()
        let validatorError = NSError(domain: "validator failed", code: 0)

        _ = await Mock.Route(session: NetworkingSession(urlSession: Mock.UrlSession(), observers: [mockObserver]),
                             responseValidator: Mock.ResponseValidator(mockValidationError: validatorError),
                             responseSerializer: Mock.ResponseSerializer<Void>()).result

        let didReceiveDidRun = await mockObserver.didReceiveDidRun
        let didFailDidRun = await mockObserver.didFailDidRun
        XCTAssertTrue(didReceiveDidRun, "didReceive should fire when URLSession returns bytes, even if validator later rejects them.")
        XCTAssertFalse(didFailDidRun, "didFail should only fire on transport-level errors, not validator failures.")
    }

    func testObserverFiresPerAttempt() async throws {
        let mockObserver = Mock.Observer()
        let mockRetrier = Mock.Interceptor(adapterResult: .doNotAdapt,
                                           retrierResult: .retryWithDelay(0))

        _ = await Mock.Route(session: NetworkingSession(urlSession: Mock.UrlSession(), retrier: mockRetrier, observers: [mockObserver]),
                             responseSerializer: Mock.ResponseSerializers<Void>([.failure(NSError(domain: "", code: 0)), .success(())])).result

        let willSendCount = await mockObserver.willSendCallCount
        let didReceiveCount = await mockObserver.didReceiveCallCount
        XCTAssertEqual(willSendCount, 2, "willSend should fire on every attempt, including retries.")
        XCTAssertEqual(didReceiveCount, 2, "didReceive should fire on every attempt where URLSession returned bytes.")
    }

    func testAllRegisteredObserversFire() async throws {
        let sessionObserverA = Mock.Observer()
        let sessionObserverB = Mock.Observer()
        let routeObserverA = Mock.Observer()
        let routeObserverB = Mock.Observer()

        _ = await Mock.Route(session: NetworkingSession(urlSession: Mock.UrlSession(),
                                                        observers: [sessionObserverA, sessionObserverB]),
                             responseSerializer: Mock.ResponseSerializer<Void>(),
                             observers: [routeObserverA, routeObserverB]).result

        for (label, observer) in [
            ("session A", sessionObserverA),
            ("session B", sessionObserverB),
            ("route A", routeObserverA),
            ("route B", routeObserverB)
        ] {
            let didRun = await observer.willSendDidRun
            XCTAssertTrue(didRun, "Observer \(label) should fire.")
        }
    }

    func testObserverFiresDidFailThenDidReceiveAcrossRetries() async throws {
        let mockObserver = Mock.Observer()
        let mockRetrier = Mock.Interceptor(adapterResult: .doNotAdapt,
                                           retrierResult: .retryWithDelay(0))
        let urlSession = Mock.UrlSessions(mockResults: [
            .failure(URLError(.timedOut)),
            .success(Data())
        ])

        _ = await Mock.Route(session: NetworkingSession(urlSession: urlSession,
                                                        retrier: mockRetrier,
                                                        observers: [mockObserver]),
                             responseSerializer: Mock.ResponseSerializer<Void>()).result

        let willSendCount = await mockObserver.willSendCallCount
        let didFailCount = await mockObserver.didFailCallCount
        let didReceiveCount = await mockObserver.didReceiveCallCount
        XCTAssertEqual(willSendCount, 2, "willSend should fire on every attempt.")
        XCTAssertEqual(didFailCount, 1, "didFail should fire exactly once for the transport-failed first attempt.")
        XCTAssertEqual(didReceiveCount, 1, "didReceive should fire exactly once for the successful second attempt.")
    }

    func testObserverDoesNotFireForMockSerializedResult() async throws {
        let mockObserver = Mock.Observer()

        _ = await Mock.Route(session: NetworkingSession(urlSession: Mock.UrlSession(), observers: [mockObserver]),
                             responseSerializer: Mock.ResponseSerializer<Void>(),
                             mockSerializedResult: .success(())).result

        let willSendDidRun = await mockObserver.willSendDidRun
        let didReceiveDidRun = await mockObserver.didReceiveDidRun
        let didFailDidRun = await mockObserver.didFailDidRun
        XCTAssertFalse(willSendDidRun)
        XCTAssertFalse(didReceiveDidRun)
        XCTAssertFalse(didFailDidRun)
    }

    func testObserverDoesNotFireWhenAdapterThrows() async throws {
        let adapterError = NSError(domain: "adapter failed", code: 0)
        let throwingAdapter = Mock.Interceptor(adapterResult: .failure(error: adapterError),
                                               retrierResult: .doNotRetry)
        let mockObserver = Mock.Observer()

        _ = await Mock.Route(session: NetworkingSession(urlSession: Mock.UrlSession(), adapter: throwingAdapter, observers: [mockObserver]),
                             responseSerializer: Mock.ResponseSerializer<Void>()).result

        let willSendDidRun = await mockObserver.willSendDidRun
        let didReceiveDidRun = await mockObserver.didReceiveDidRun
        let didFailDidRun = await mockObserver.didFailDidRun
        XCTAssertFalse(willSendDidRun, "willSend should not fire when no URLRequest is available.")
        XCTAssertFalse(didReceiveDidRun)
        XCTAssertFalse(didFailDidRun)
    }
}
