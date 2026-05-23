
# ``PopNetworking/NetworkingStreamRoute``

A route whose response arrives incrementally — the consumer iterates typed chunks as bytes are received. Useful for Server-Sent Events, NDJSON feeds, large file downloads, and LLM token streams.

## Topics

### Building the URLRequest

Request construction is inherited from ``NetworkingEndpoint``.

- ``NetworkingEndpoint/method``
- ``NetworkingEndpoint/baseUrl``
- ``NetworkingEndpoint/path``
- ``NetworkingEndpoint/NetworkingRouteHttpHeaders``
- ``NetworkingEndpoint/headers``
- ``NetworkingEndpoint/parameterEncoding``
- ``NetworkingEndpoint/timeoutInterval``
- ``NetworkingEndpoint/urlRequest``

### NetworkingSession

``NetworkingStreamRoute``s are run on an instance of ``NetworkingSession``. To run a route, call ``NetworkingSessionProtocol/executeStream(route:)`` and pass in an instance of a ``NetworkingStreamRoute``.

- ``NetworkingEndpoint/session``

### Ways to run a NetworkingStreamRoute

- ``stream``
- ``task(priority:onChunk:)``

### Stream handling & parsing

- ``serializer``
- ``Serializer``
- ``NetworkingSerializers``
- ``byteChunkSize``
- ``mockChunks``

### Advanced Usage

- ``NetworkingHooks/adapter``
- ``NetworkingHooks/retrier``
- ``NetworkingHooks/interceptor``
- ``NetworkingHooks/observers``
