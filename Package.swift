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
    dependencies: [
        .package(url: "https://github.com/ml-explore/mlx-swift-lm", from: "2.31.3"),
    ],
    targets: [
        .target(
            name: "SwiftIntelligence",
            dependencies: [
                .product(name: "MLXLLM", package: "mlx-swift-lm"),
                .product(name: "MLXLMCommon", package: "mlx-swift-lm"),
            ]),
        .testTarget(
            name: "SwiftIntelligenceTests",
            dependencies: ["SwiftIntelligence"]),
    ]
)
