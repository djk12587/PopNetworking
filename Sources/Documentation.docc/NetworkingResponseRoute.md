
# ``PopNetworking/NetworkingResponseRoute``

A route whose response is collected and parsed into one typed value.

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

``NetworkingResponseRoute``s are run on an instance of ``NetworkingSession``. To run a route, call ``NetworkingSessionProtocol/execute(route:)`` and pass in an instance of a ``NetworkingResponseRoute``.

- ``NetworkingEndpoint/session``

### Ways to run a NetworkingResponseRoute

- ``run``
- ``request(priority:completeOn:completion:)``
- ``result``
- ``task(priority:)``
- ``publisher``
- ``failablePublisher``

### Response handling & parsing

- ``serializer``
- ``Serializer``
- ``NetworkingSerializers``
- ``mockSerializedResult``

### Advanced Usage

- ``NetworkingHooks/adapter``
- ``NetworkingHooks/retrier``
- ``NetworkingHooks/interceptor``
- ``NetworkingHooks/observers``
- ``repeater``
