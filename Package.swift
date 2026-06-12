// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "kujto",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .executable(name: "kujto", targets: ["KujtoCLI"]),
        .library(name: "KujtoCore", targets: ["KujtoCore"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.3.0")
    ],
    targets: [
        .target(
            name: "KujtoCore",
            path: "Sources/KujtoCore"
        ),
        .executableTarget(
            name: "KujtoCLI",
            dependencies: [
                "KujtoCore",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ],
            path: "Sources/KujtoCLI"
        ),
        .testTarget(
            name: "KujtoCoreTests",
            dependencies: ["KujtoCore"],
            path: "Tests/KujtoCoreTests"
        )
    ]
)
