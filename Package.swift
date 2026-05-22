// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "sidesync",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.3.0"),
    ],
    targets: [
        // Shared library — models, services, utilities
        .target(
            name: "SideSyncLib",
            path: "Sources/SideSyncLib"
        ),

        // CLI tool
        .executableTarget(
            name: "sidesync",
            dependencies: [
                "SideSyncLib",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            path: "Sources/sidesync"
        ),

        // SwiftUI GUI app
        .executableTarget(
            name: "SideSyncApp",
            dependencies: [
                "SideSyncLib",
            ],
            path: "Sources/SideSyncApp"
        ),
    ]
)
