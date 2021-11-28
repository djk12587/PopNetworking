//
//  File.swift
//  
//
//  Created by Dan Koza on 11/26/21.
//

import XCTest
import Combine
@testable import PopNetworking

class CombineTests: XCTestCase {

    func testPublisherSuccess() {
        let expectation = expectation(description: "wait for response")
        var cancellables = Set<AnyCancellable>()

        let mockRoute = Mock.Route(responseSerializer: Mock.ResponseSerializer(.success("mock_response")))
        mockRoute.publisher.sink { completion in
            XCTAssertEqual(completion, .finished)
            expectation.fulfill()
        } receiveValue: { result in
            switch result {
                case .success(let response):
                    XCTAssertEqual(response, "mock_response")
                case .failure:
                    XCTFail("request should not fail")
            }
        }.store(in: &cancellables)

        waitForExpectations(timeout: 5)
    }

    func testPublisherFailure() {
        let expectation = expectation(description: "wait for response")
        var cancellables = Set<AnyCancellable>()

        let mockError = NSError(domain: "mockError", code: 1)
        let mockRoute = Mock.Route<Void>(responseSerializer: Mock.ResponseSerializer(.failure(mockError)))
        mockRoute.publisher.sink { completion in
            XCTAssertEqual(completion, .finished)
            expectation.fulfill()
        } receiveValue: { result in
            switch result {
                case .success:
                    XCTFail("request should fail")
                case .failure(let error):
                    XCTAssertEqual(error as NSError, mockError)
            }
        }.store(in: &cancellables)

        waitForExpectations(timeout: 5)
    }

    func testFailablePublisherSuccess() {
        let expectation = expectation(description: "wait for response")
        var cancellables = Set<AnyCancellable>()

        let mockRoute = Mock.Route(responseSerializer: Mock.ResponseSerializer(.success("mock_response")))
        mockRoute.failablePublisher.sink { completion in
            if case .failure = completion {
                XCTFail("request should not fail")
            }
            expectation.fulfill()
        } receiveValue: { result in
            XCTAssertEqual(result, "mock_response")
        }.store(in: &cancellables)

        waitForExpectations(timeout: 5)
    }

    func testFailablePublisherFailure() {
        let expectation = expectation(description: "wait for response")
        var cancellables = Set<AnyCancellable>()

        let mockError = NSError(domain: "mockError", code: 1)
        let mockRoute = Mock.Route<Void>(responseSerializer: Mock.ResponseSerializer(.failure(mockError)))
        mockRoute.failablePublisher.sink { completion in
            switch completion {
                case .failure(let error):
                    XCTAssertEqual(error as NSError, mockError)
                case .finished:
                    XCTFail("request should fail")
            }
            expectation.fulfill()
        } receiveValue: { result in
            XCTFail("request should fail")
        }.store(in: &cancellables)

        waitForExpectations(timeout: 5)
    }

    func testCancellation() {
        var cancellables = Set<AnyCancellable>()
        let expectation = expectation(description: "wait for response")

        let mockRoute = Mock.Route<String>(session: NetworkingSession())
        let cancellable = mockRoute.publisher
            .handleEvents(receiveCancel: {
                expectation.fulfill()
            })
            .sink(receiveValue: { _ in })

        cancellable.store(in: &cancellables)
        cancellable.cancel()

        waitForExpectations(timeout: 5)
    }
}
