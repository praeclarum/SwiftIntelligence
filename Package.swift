// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SwiftIntelligence",
    platforms: [.visionOS(.v1), .iOS(.v12), .watchOS(.v6), .tvOS(.v15), .macOS(.v11), .macCatalyst(.v13)],
    products: [
        .library(
            name: "SwiftIntelligence",
            targets: ["SwiftIntelligence"]),
    ],
    targets: [
        .target(
            name: "SwiftIntelligence"),
        .testTarget(
            name: "SwiftIntelligenceTests",
            dependencies: ["SwiftIntelligence"]),
    ]
)
