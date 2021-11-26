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

    func testResultPublisherSuccess() throws {
        var cancellables = Set<AnyCancellable>()
        let mockRoute = Mock.Route<Int>(responseSerializer: Mock.ResponseSerializer(.success(200)))
        mockRoute.publisher.sink { completion in
            XCTAssertEqual(completion, .finished)
        } receiveValue: { result in
            switch result {
                case .success(let response):
                    XCTAssertEqual(response, 200)
                case .failure:
                    XCTFail("request should not fail")
            }
        }.store(in: &cancellables)
    }

    func testResultPublisherFailure() throws {
        var cancellables = Set<AnyCancellable>()
        let mockError = NSError(domain: "mockError", code: 1)
        let mockRoute = Mock.Route<Void>(responseSerializer: Mock.ResponseSerializer(.failure(mockError)))
        mockRoute.publisher.sink { completion in
            XCTAssertEqual(completion, .finished)
        } receiveValue: { result in
            switch result {
                case .success:
                    XCTFail("request should fail")
                case .failure(let error):
                    XCTAssertEqual(error as NSError, mockError)
            }
        }.store(in: &cancellables)
    }

    func testFailableResultPublisherSuccess() throws {
        var cancellables = Set<AnyCancellable>()
        let mockRoute = Mock.Route<Int>(responseSerializer: Mock.ResponseSerializer(.success(200)))
        mockRoute.failablePublisher.sink { completion in
            if case .failure = completion {
                XCTFail("request should not fail")
            }
        } receiveValue: { result in
            XCTAssertEqual(result, 200)
        }.store(in: &cancellables)
    }

    func testFailableResultPublisherFailure() throws {
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
        } receiveValue: { result in
            XCTFail("request should fail")
        }.store(in: &cancellables)
    }
}
