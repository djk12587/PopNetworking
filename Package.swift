// swift-tools-version:6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "PopNetworking",
    platforms: [
        .iOS(.v13),
        .tvOS(.v13),
        .watchOS(.v6),
        .macOS(.v10_15)
    ],
    products: [
        .library(
            name: "PopNetworking",
            targets: ["PopNetworking"]
        ),
    ],
    targets: [
        .target(
            name: "PopNetworking",
            path: "Sources",
            swiftSettings: [
              .enableUpcomingFeature("StrictConcurrency")
            ]
        ),
        .testTarget(
            name: "PopNetworkingTests",
            dependencies: ["PopNetworking"],
            path: "Tests"
        )
    ]
)
