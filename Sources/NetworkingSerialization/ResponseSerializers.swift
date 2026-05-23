//
//  ResponseSerializers.swift
//  PopNetworking
//
//  Created by Daniel Koza on 1/9/21.
//  Copyright © 2021 Daniel Koza. All rights reserved.
//

import Foundation

/// Namespace for prebuilt ``NetworkingResponseSerializer`` and
/// ``NetworkingStreamSerializer`` implementations.
///
/// Serializers are split into two inner enums by the kind of route they serve. Each inner
/// type is declared in its own file under the matching folder:
/// * ``Response`` — serializers for ``NetworkingResponseRoute`` (single request/response).
///   See `Sources/NetworkingSerialization/Response/`.
/// * ``Stream`` — serializers for ``NetworkingStreamRoute`` (incremental response).
///   See `Sources/NetworkingSerialization/Stream/`.
///
/// Example usage:
/// ```swift
/// // Response route, decoded as a User:
/// var serializer: NetworkingSerializers.Response.Decodable<User> { .init() }
///
/// // Stream route, one Decodable per NDJSON line:
/// var serializer: NetworkingSerializers.Stream.Decodable<LogEntry> { .init() }
/// ```
public enum NetworkingSerializers {

    /// Serializers for ``NetworkingResponseRoute`` (single request/response). Concrete
    /// serializers extend this enum from individual files under
    /// `Sources/NetworkingSerialization/Response/`.
    public enum Response {}

    /// Serializers for ``NetworkingStreamRoute`` (incremental response). Concrete
    /// serializers extend this enum from individual files under
    /// `Sources/NetworkingSerialization/Stream/`.
    public enum Stream {}
}
