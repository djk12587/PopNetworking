//
//  File.swift
//  
//
//  Created by Dan_Koza on 2/8/21.
//

import Foundation

internal protocol NetworkingSessionDataTaskDelegate: class {
    func networkingSessionDataTaskIsReadyToExecute(networkingSessionDataTask: NetworkingSessionDataTask)
    func restart(urlRequest: URLRequest, accompaniedWith networkingSessionDataTask: NetworkingSessionDataTask)
}

public class NetworkingSessionDataTask {

    internal var request: URLRequest?
    internal var dataTask: URLSessionDataTask? = nil

    internal let urlRequestConvertibleError: Error?
    private(set) var retryCount = 0
    private weak var requestRetrier: NetworkingRequestRetrier?
    private weak var delegate: NetworkingSessionDataTaskDelegate?

    private var serializeResponses: [(DataTaskResponseContainer) -> Void] = []

    public var task: URLSessionTask? { dataTask }

    internal init(requestConvertible: URLRequestConvertible?,
                  requestRetrier: NetworkingRequestRetrier? = nil,
                  delegate: NetworkingSessionDataTaskDelegate) {

        self.delegate = delegate
        self.requestRetrier = requestRetrier

        do {
            request = try requestConvertible?.asURLRequest()
            urlRequestConvertibleError = nil
        }
        catch {
            request = nil
            urlRequestConvertibleError = error
        }
    }

    @discardableResult
    public func appendResponse<Serializer: NetworkingResponseSerializer>(serializer: Serializer,
                                                                         runCompletionHandlerOn queue: DispatchQueue = .main,
                                                                         completionHandler: @escaping (Result<Serializer.SerializedObject, Error>) -> Void) -> Self {

        let serializeResponseFunction = createSerializeResponseFunction(serializer: serializer,
                                                                        runUrlRequestCompletionHandlerOn: queue,
                                                                        urlRequestCompletionHandler: completionHandler)
        serializeResponses.append(serializeResponseFunction)

        return self
    }

    @discardableResult
    public func execute() -> NetworkingSessionDataTask {
        delegate?.networkingSessionDataTaskIsReadyToExecute(networkingSessionDataTask: self)
        return self
    }

    @discardableResult
    internal func executeResponseSerializers(with dataTaskResponseContainer: DataTaskResponseContainer) -> Self {
        serializeResponses.forEach { $0(dataTaskResponseContainer) }

        return self
    }

    internal func incrementRetryCount() {
        retryCount += 1
    }
}

extension NetworkingSessionDataTask {

    private func createSerializeResponseFunction<Serializer: NetworkingResponseSerializer>(serializer: Serializer,
                                                                                           runUrlRequestCompletionHandlerOn queue: DispatchQueue,
                                                                                           urlRequestCompletionHandler: @escaping (Result<Serializer.SerializedObject, Error>) -> Void) -> ((DataTaskResponseContainer) -> Void) {

        let serializeResponseFunction = { [weak self] (dataTaskResponseContainer: DataTaskResponseContainer) in
            guard let self = self else { return }

            let serializerResult = serializer.serialize(request: self.request,
                                                        response: dataTaskResponseContainer.response,
                                                        data: dataTaskResponseContainer.data,
                                                        error: dataTaskResponseContainer.error)

            //Check if the response contains an error, if not, trigger the completionHandler.
            guard let error = dataTaskResponseContainer.error ?? serializerResult.error,
                  let delegate = self.delegate,
                  let retrier = self.requestRetrier,
                  let urlRequest = self.request else {

                queue.async { urlRequestCompletionHandler(serializerResult) }
                return
            }

            //If there is an error, we now ask the retrier if the failed request should be restarted or not
            retrier.retry(urlRequest: urlRequest,
                          dueTo: error,
                          urlResponse: dataTaskResponseContainer.response ?? HTTPURLResponse(),
                          retryCount: self.retryCount) { retrierResult in

                switch retrierResult {
                    case .doNotRetry:
                        queue.async { urlRequestCompletionHandler(serializerResult) }
                    case .retry:
                        self.incrementRetryCount()
                        delegate.restart(urlRequest: urlRequest, accompaniedWith: self)
                }
            }
        }

        return serializeResponseFunction
    }
}

private extension Result {
    var error: Error? {
        guard case let .failure(error) = self else { return nil }
        return error
    }
}

internal struct DataTaskResponseContainer {
    let response: HTTPURLResponse?
    let data: Data?
    let error: Error?
}
