//
//  File.swift
//  
//
//  Created by Dan_Koza on 2/8/21.
//

import Foundation

internal protocol NetworkingSessionDataTaskDelegate: class {
    func networkingSessionDataTaskIsReadyToExecute(urlRequest: URLRequest, accompaniedWith networkingSessionDataTask: NetworkingSessionDataTask)
}

public class NetworkingSessionDataTask {

    private let requestConvertible: URLRequestConvertible
    private var originalRequest: URLRequest?
    private var adaptedRequest: URLRequest?
    private var mostUpToDateRequest: URLRequest? { adaptedRequest ?? originalRequest }

    internal var dataTask: URLSessionDataTask? = nil

    private(set) var retryCount = 0
    private weak var requestAdapter: NetworkingRequestAdapter?
    private weak var requestRetrier: NetworkingRequestRetrier?
    private weak var delegate: NetworkingSessionDataTaskDelegate?

    private var queuedResponseSerializers: [(DataTaskResponseContainer) -> Void] = []

    public var task: URLSessionTask? { dataTask }

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

        queueResponseSerialization(serializeAction: responseSerializationMode.serializationAction,
                                   runUrlRequestCompletionHandlerOn: queue,
                                   urlRequestCompletionHandler: completionHandler)
        return self
    }

    @discardableResult
    public func execute() -> NetworkingSessionDataTask {

        do {
            let request: URLRequest
            if let urlRequest = self.mostUpToDateRequest {
                request = urlRequest
            }
            else {
                request = try requestConvertible.asUrlRequest()
                originalRequest = request
            }

            let adaptedRequest = try runAdapter(urlRequest: request)
            delegate?.networkingSessionDataTaskIsReadyToExecute(urlRequest: adaptedRequest ?? request, accompaniedWith: self)
        }
        catch {
            executeResponseSerializers(with: DataTaskResponseContainer(response: nil,
                                                                       data: nil,
                                                                       error: error))
        }

        return self
    }

    @discardableResult
    internal func executeResponseSerializers(with dataTaskResponseContainer: DataTaskResponseContainer) -> Self {
        queuedResponseSerializers.forEach { $0(dataTaskResponseContainer) }

        return self
    }
}

extension NetworkingSessionDataTask {

    private func runAdapter(urlRequest: URLRequest) throws -> URLRequest? {
        do {
            self.adaptedRequest = try requestAdapter?.adapt(urlRequest: urlRequest)
            return self.adaptedRequest
        }
        catch {
            throw error
        }
    }

    private func queueResponseSerialization<ResponseModel>(serializeAction: @escaping (NetworkingRawResponse) -> Result<ResponseModel, Error>,
                                                           runUrlRequestCompletionHandlerOn queue: DispatchQueue,
                                                           urlRequestCompletionHandler: @escaping (Result<ResponseModel, Error>) -> Void) {

        let responseSerialization = { [weak self] (dataTaskResponseContainer: DataTaskResponseContainer) in
            guard let self = self else { return }

            let networkingRawResponse = NetworkingRawResponse(self.mostUpToDateRequest,
                                                           dataTaskResponseContainer.response,
                                                           dataTaskResponseContainer.data,
                                                           dataTaskResponseContainer.error)
            let serializedResult = serializeAction(networkingRawResponse)
            //Check if the response contains an error, if not, trigger the completionHandler.
            guard let error = dataTaskResponseContainer.error ?? serializedResult.error,
                  let retrier = self.requestRetrier,
                  let urlRequest = self.mostUpToDateRequest else {

                queue.async { urlRequestCompletionHandler(serializedResult) }
                return
            }

            //If there is an error, we now ask the retrier if the failed request should be restarted or not
            retrier.retry(urlRequest: urlRequest,
                          dueTo: error,
                          urlResponse: dataTaskResponseContainer.response ?? HTTPURLResponse(),
                          retryCount: self.retryCount) { retrierResult in

                switch retrierResult {
                    case .doNotRetry:
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

internal struct DataTaskResponseContainer {
    let response: HTTPURLResponse?
    let data: Data?
    let error: Error?
}
