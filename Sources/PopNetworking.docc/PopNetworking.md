# ``PopNetworking``

A protocol-oriented HTTP networking layer for Swift. Built with Swift 6 and strict concurrency.

## Quick Start

Define an endpoint by conforming to ``NetworkingRoute``:

```swift
struct GetUser: NetworkingRoute {
    let userId: Int

    var baseUrl: String { "https://api.example.com" }
    var path: String { "users/\(userId)" }
    var method: NetworkingRouteHttpMethod { .get }
    var responseSerializer: NetworkingResponseSerializers.DecodableResponseSerializer<User> {
        .init()
    }
}
```

Execute it:

```swift
let user = try await GetUser(userId: 42).run
```

## Topics

### Defining Routes

- ``NetworkingRoute``
- ``Route``
- ``NetworkingRouteHttpMethod``
- ``NetworkingRouteParameterEncoding``

### Executing Routes

- ``NetworkingSession``
- ``NetworkingSessionProtocol``
- ``URLSessionProtocol``

### Response Handling

- ``NetworkingResponseSerializer``
- ``NetworkingResponseSerializers``
- ``NetworkingResponseValidator``

### Request Modifiers

- ``NetworkingAdapter``
- ``NetworkingRetrier``
- ``NetworkingInterceptor``
- ``RouteInterceptor``
- ``NetworkingRetrierResult``
- ``NetworkingPriority``

### Parameter Encoding

- ``URLEncoding``
- ``JSONEncoding``
- ``MultipartEncoding``
- ``MultipartPart``

### Combine Support

- ``NetworkingRoutePublisher``
- ``NetworkingRouteFailablePublisher``
