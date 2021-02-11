//
//  File.swift
//  
//
//  Created by Dan_Koza on 2/8/21.
//

import Foundation

internal protocol NetworkingSessionDataTaskDelegate: class {
    func restart(networkingSessionDataTask: NetworkingSessionDataTask)
}

public class NetworkingSessionDataTask {

    internal var request: URLRequest?
    internal var dataTask: URLSessionDataTask? = nil

    private(set) var urlRequestInitializerError: Error?
    private var retryCount = 0
    private weak var requestRetrier: NetworkingRequestRetrier?
    private weak var delegate: NetworkingSessionDataTaskDelegate?

    private var serializeResponses: [(DataTaskResponseContainer) -> Void] = []

    public var task: URLSessionTask? { dataTask }

    internal init(requestConvertible: URLRequestConvertible,
                  requestRetrier: NetworkingRequestRetrier? = nil,
                  delegate: NetworkingSessionDataTaskDelegate? = nil) {

        self.delegate = delegate
        self.requestRetrier = requestRetrier

        do {
            self.request = try requestConvertible.asURLRequest()
        }
        catch {
            self.urlRequestInitializerError = error
            self.request = nil
        }
    }

    @discardableResult
    internal func executeResponseSerializers(with dataTaskResponseContainer: DataTaskResponseContainer) -> Self {
        serializeResponses.forEach { $0(dataTaskResponseContainer) }

        return self
    }

    @discardableResult
    public func response<Serializer: NetworkingResponseSerializer>(serializer: Serializer,
                                                                   runCompletionHandlerOn queue: DispatchQueue = .main,
                                                                   completionHandler: @escaping (Result<Serializer.SerializedObject, Error>) -> Void) -> Self {

        let serializeResponseFunction = createSerializeResponseFunction(serializer: serializer,
                                                                        runUrlRequestCompletionHandlerOn: queue,
                                                                        urlRequestCompletionHandler: completionHandler)
        serializeResponses.append(serializeResponseFunction)

        return self
    }
}

extension NetworkingSessionDataTask {

    private func createSerializeResponseFunction<Serializer: NetworkingResponseSerializer>(serializer: Serializer,
                                                                                           runUrlRequestCompletionHandlerOn queue: DispatchQueue,
                                                                                           urlRequestCompletionHandler: @escaping (Result<Serializer.SerializedObject, Error>) -> Void) -> ((DataTaskResponseContainer) -> Void) {

        let serializeResponseFunction = { [weak self] (dataTaskResponseContainer: DataTaskResponseContainer) in
            guard let self = self else { return }

            let serializerResult: Result<Serializer.SerializedObject, Error> = Result {
                try serializer.serialize(request: self.request,
                                         response: dataTaskResponseContainer.response,
                                         data: dataTaskResponseContainer.data,
                                         error: self.urlRequestInitializerError ?? dataTaskResponseContainer.error)
            }

            //Check if the response contains an error, if not, trigger the completionHandler.
            guard let error = self.urlRequestInitializerError ?? dataTaskResponseContainer.error ?? serializerResult.error,
                  let delegate = self.delegate,
                  let retrier = self.requestRetrier,
                  let urlRequest = self.request,
                  let urlResponse = dataTaskResponseContainer.response else {

                queue.async { urlRequestCompletionHandler(serializerResult) }
                return
            }

            //If there is an error, we now ask the retrier if the failed request should be restarted or not
            retrier.retry(urlRequest: urlRequest,
                          dueTo: error,
                          urlResponse: urlResponse,
                          retryCount: self.retryCount) { retrierResult in

                switch retrierResult {
                    case .doNotRetry:
                        queue.async { urlRequestCompletionHandler(serializerResult) }
                    case .retry:
                        self.retryCount += 1
                        delegate.restart(networkingSessionDataTask: self)
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
