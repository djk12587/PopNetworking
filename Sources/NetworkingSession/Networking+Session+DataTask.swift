//
//  File.swift
//  
//
//  Created by Dan_Koza on 2/8/21.
//

import Foundation

internal protocol NetworkingSessionDataTaskDelegate: AnyObject {
    func networkingSessionDataTaskIsReadyToExecute(urlRequest: URLRequest, accompaniedWith networkingSessionDataTask: NetworkingSessionDataTask)
}

public class NetworkingSessionDataTask: Cancellable {

    private let requestConvertible: URLRequestConvertible
    private var request: URLRequest?

    internal var dataTask: URLSessionDataTask? = nil
    private var wasCancelled = false

    private(set) var retryCount = 0
    private weak var requestAdapter: NetworkingRequestAdapter?
    private weak var requestRetrier: NetworkingRequestRetrier?
    private weak var delegate: NetworkingSessionDataTaskDelegate?

    private var queuedResponseSerializers: [(NetworkingRawResponse) -> Void] = []

    public var cancellableTask: Cancellable {
        return self
    }

    public func cancel() {
        wasCancelled = true
        dataTask?.cancel()
    }

    internal init(requestConvertible: URLRequestConvertible,
                  requestAdapter: NetworkingRequestAdapter?,
                  requestRetrier: NetworkingRequestRetrier?,
                  delegate: NetworkingSessionDataTaskDelegate) {

        self.requestConvertible = requestConvertible
        self.delegate = delegate
        self.requestAdapter = requestAdapter
        self.requestRetrier = requestRetrier
    }

    @discardableResult
    public func serializeResponse<ResponseSerializer: NetworkingResponseSerializer>(with responseSerializationMode: NetworkingResponseSerializationMode<ResponseSerializer>,
                                                                                    runCompletionHandlerOn queue: DispatchQueue = .main,
                                                                                    completionHandler: @escaping (Result<ResponseSerializer.SerializedObject, Error>) -> Void) -> Self {

        queueResponseSerialization(serialize: responseSerializationMode.serialize,
                                   runUrlRequestCompletionHandlerOn: queue,
                                   urlRequestCompletionHandler: completionHandler)
        return self
    }

    @discardableResult
    public func execute() -> NetworkingSessionDataTask {

        do {
            let urlRequest = try request ?? requestConvertible.asUrlRequest()
            request = urlRequest
            let adaptedUrlRequest = try requestAdapter?.adapt(urlRequest: urlRequest)
            request = adaptedUrlRequest
            delegate?.networkingSessionDataTaskIsReadyToExecute(urlRequest: adaptedUrlRequest ?? urlRequest,
                                                                accompaniedWith: self)
        }
        catch {
            executeResponseSerializers(with: NetworkingRawResponse(urlRequest: request,
                                                                   urlResponse: nil,
                                                                   data: nil,
                                                                   error: error))
        }

        return self
    }

    @discardableResult
    internal func executeResponseSerializers(with rawResponse: NetworkingRawResponse) -> Self {
        queuedResponseSerializers.forEach { $0(rawResponse) }
        return self
    }
}

extension NetworkingSessionDataTask {

    private func queueResponseSerialization<ResponseModel>(serialize: @escaping (NetworkingRawResponse) -> Result<ResponseModel, Error>,
                                                           runUrlRequestCompletionHandlerOn queue: DispatchQueue,
                                                           urlRequestCompletionHandler: @escaping (Result<ResponseModel, Error>) -> Void) {

        let responseSerialization = { [weak self] (rawResponse: NetworkingRawResponse) in
            guard let self = self else { return }

            let serializedResult = serialize(rawResponse)
            //Check if the response contains an error, if not, trigger the completionHandler.
            guard
                let error = rawResponse.error ?? serializedResult.error,
                let retrier = self.requestRetrier,
                let urlRequest = rawResponse.urlRequest
            else {
                queue.async { urlRequestCompletionHandler(serializedResult) }
                return
            }

            //If there is an error, we now ask the retrier if the failed request should be restarted or not
            retrier.retry(urlRequest: urlRequest,
                          dueTo: error,
                          urlResponse: rawResponse.urlResponse ?? HTTPURLResponse(),
                          retryCount: self.retryCount) { [weak self] retrierResult in
                guard let self = self else { return }

                switch retrierResult {
                    case .doNotRetry,
                         .retry where self.wasCancelled:
                        queue.async { urlRequestCompletionHandler(serializedResult) }

                    case .retry:
                        self.retryCount += 1
                        self.execute()
                }
            }
        }

        queuedResponseSerializers.append(responseSerialization)
    }
}

private extension Result {
    var error: Error? {
        guard case let .failure(error) = self else { return nil }
        return error
    }
}
