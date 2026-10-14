// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Uncork",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Uncork", targets: ["Uncork"]),
        .library(name: "UncorkCore", targets: ["UncorkCore"]),
    ],
    targets: [
        .target(name: "UncorkCore"),
        .executableTarget(name: "Uncork", dependencies: ["UncorkCore"]),
        .testTarget(name: "UncorkCoreTests", dependencies: ["UncorkCore"]),
    ]
)
