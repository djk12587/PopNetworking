// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "PopNetworking",
    products: [
        .library(
            name: "PopNetworking",
            targets: ["PopNetworking"]
        ),
    ],
    targets: [
        .target(
            name: "PopNetworking",
            path: "Sources"
        ),
        .testTarget(
            name: "PopNetworkingTests",
            dependencies: ["PopNetworking"]
        )
    ]
)
