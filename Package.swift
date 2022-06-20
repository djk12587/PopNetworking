// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "PopNetworking",
    platforms: [
        .macOS(.v10_15),
        .iOS(.v13),
        .tvOS(.v13),
        .watchOS(.v6)
    ],
    products: [
        .library(
            name: "PopNetworking",
            targets: ["PopNetworking"]
        ),
    ],
    dependencies: [
        // other dependencies
        .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "PopNetworking",
            path: "Sources"
        ),
        .testTarget(
            name: "PopNetworkingTests",
            dependencies: ["PopNetworking"],
            path: "Tests"
        )
    ]
)
