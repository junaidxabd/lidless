// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LidlessCore",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "LidlessCore", targets: ["LidlessCore"])
    ],
    targets: [
        .target(name: "LidlessCore"),
        .testTarget(name: "LidlessCoreTests", dependencies: ["LidlessCore"])
    ]
)
