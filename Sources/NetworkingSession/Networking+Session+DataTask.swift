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

    private var serializeResponses: [(DataTaskResponseContainer) -> Void] = []

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

        do {
            let request: URLRequest
            if let urlRequest = self.mostUpToDateRequest {
                request = urlRequest
            }
            else {
                request = try requestConvertible.asUrlRequest()
                originalRequest = request
            }

            delegate?.networkingSessionDataTaskIsReadyToExecute(urlRequest: try runAdapter(urlRequest: request) ?? request, accompaniedWith: self)
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
        serializeResponses.forEach { $0(dataTaskResponseContainer) }

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

    private func createSerializeResponseFunction<Serializer: NetworkingResponseSerializer>(serializer: Serializer,
                                                                                           runUrlRequestCompletionHandlerOn queue: DispatchQueue,
                                                                                           urlRequestCompletionHandler: @escaping (Result<Serializer.SerializedObject, Error>) -> Void) -> ((DataTaskResponseContainer) -> Void) {

        let serializeResponseFunction = { [weak self] (dataTaskResponseContainer: DataTaskResponseContainer) in
            guard let self = self else { return }

            let serializerResult = serializer.serialize(request: self.mostUpToDateRequest,
                                                        response: dataTaskResponseContainer.response,
                                                        data: dataTaskResponseContainer.data,
                                                        error: dataTaskResponseContainer.error)

            //Check if the response contains an error, if not, trigger the completionHandler.
            guard let error = dataTaskResponseContainer.error ?? serializerResult.error,
                  let retrier = self.requestRetrier,
                  let urlRequest = self.mostUpToDateRequest else {

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
                        self.retryCount += 1
                        self.execute()
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
