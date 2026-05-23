# ``PopNetworking``

A protocol-oriented HTTP networking layer for Swift. Built with Swift 6 and strict concurrency.

PopNetworking exposes two execution surfaces:

- ``NetworkingResponseRoute`` — the response is collected and parsed into one typed value.
- ``NetworkingStreamRoute`` — the consumer iterates typed chunks as bytes arrive. Useful for Server-Sent Events, NDJSON feeds, large file downloads, and LLM token streams.

Both share the same request-construction (``NetworkingEndpoint``) and hook (``NetworkingHooks``) model.

## Quick Start — Response Routes

Define an endpoint by conforming to ``NetworkingResponseRoute``:

```swift
struct GetUser: NetworkingResponseRoute {
    let userId: Int

    var baseUrl: String { "https://api.example.com" }
    var path: String { "users/\(userId)" }
    var method: NetworkingRouteHttpMethod { .get }
    var serializer: NetworkingSerializers.Response.Decodable<User> {
        .init()
    }
}
```

Execute it:

```swift
let user = try await GetUser(userId: 42).run
```

For ad-hoc requests that don't need a dedicated `struct`, use ``ResponseRoute``:

```swift
let user = try await ResponseRoute(
    baseUrl: "https://api.example.com",
    path: "users/42",
    serializer: NetworkingSerializers.Response.Decodable<User>()
).run
```

## Quick Start — Stream Routes

Define a streaming endpoint by conforming to ``NetworkingStreamRoute``, or use the concrete ``StreamRoute`` for one-off requests:

```swift
let chatStream = StreamRoute(
    baseUrl: "https://api.example.com",
    path: "chat",
    method: .post,
    parameterEncoding: .json(params: ["prompt": "hello"]),
    serializer: NetworkingSerializers.Stream.SSE()
)

for try await event in try await chatStream.stream {
    print(event.data)
}
```

Or wrap the loop in a cancellable Task via ``NetworkingStreamRoute/task(priority:onChunk:)``:

```swift
let handle = chatStream.task { event in
    await store.append(event.data)
}
// Stop streaming at any time:
handle.cancel()
```

## Topics

### Response Routes

- ``NetworkingResponseRoute``
- ``ResponseRoute``
- ``NetworkingResponseSerializer``

### Stream Routes

- ``NetworkingStreamRoute``
- ``StreamRoute``
- ``NetworkingStreamSerializer``
- ``networkingDefaultByteChunkSize``

### Built-in Serializers

- ``NetworkingSerializers``

### Shared Route Foundations

- ``NetworkingEndpoint``
- ``NetworkingHooks``
- ``NetworkingRouteHttpMethod``
- ``NetworkingRouteParameterEncoding``

### Executing Routes

- ``NetworkingSession``
- ``NetworkingSessionProtocol``
- ``URLSessionProtocol``

### Request Hooks

- ``NetworkingAdapter``
- ``NetworkingRetrier``
- ``NetworkingInterceptor``
- ``NetworkingTransportObserver``
- ``RouteInterceptor``
- ``NetworkingRetrierResult``
- ``NetworkingPriority``

### Parameter Encoding

- ``URLEncoding``
- ``JSONEncoding``
- ``MultipartEncoding``
- ``MultipartPart``

### Combine Support

- ``NetworkingResponseRoutePublisher``
- ``NetworkingResponseRouteFailablePublisher``
