// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "SwiftIntelligence",
    platforms: [.visionOS(.v26), .iOS(.v26), .watchOS(.v26), .tvOS(.v26), .macOS(.v26), .macCatalyst(.v26)],
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
