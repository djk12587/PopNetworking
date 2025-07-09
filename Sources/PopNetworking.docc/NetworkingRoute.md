
# ``PopNetworking/NetworkingRoute``

## Topics

### Building the URLRequest
- ``method``
- ``baseUrl``
- ``path``
- ``NetworkingRouteHttpHeaders``
- ``headers-7smdy``
- ``parameterEncoding-17u8i``
- ``timeoutInterval-21jp1``
- ``urlRequest-5u991``

### NetworkingSession
``NetworkingRoute``'s are ran on an instance of ``NetworkingSession``. To run a route, call ``NetworkingSession/execute(route:)`` and pass in an instance of a ``NetworkingRoute``.
- ``session-5s3b3``

### Ways to run a NetworkingRoute
- ``run``
- ``request(priority:completeOn:completion:)``
- ``result``
- ``task(priority:)``
- ``publisher``
- ``failablePublisher``

### Response handling & parsing
- ``responseSerializer``
- ``ResponseSerializer``
- ``NetworkingResponseSerializers``
- ``responseValidator-220e4``
- ``mockSerializedResult-62avc``

### Advanced Usage
- ``adapter-8np6``
- ``retrier-9650z``
- ``interceptor-pstd``
- ``repeater-397rr``
- ``Repeater``
