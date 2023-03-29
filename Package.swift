// swift-tools-version:5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "YourGoal",
    platforms: [
        .macOS(.v12)
    ],    
    products: [
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.0.0"),
        .package(url: "https://github.com/dylanshine/openai-kit.git", from: "1.0.0")
    ],
    targets: [
        .executableTarget(name: "yourgoal", dependencies: [
            .product(name: "ArgumentParser", package: "swift-argument-parser"),
            .product(name: "OpenAIKit", package: "openai-kit")
        ])
    ]
)
