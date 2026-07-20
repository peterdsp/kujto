// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "kujto",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .executable(name: "kujto", targets: ["KujtoCLI"]),
        .library(name: "KujtoCore", targets: ["KujtoCore"]),
        .library(name: "KujtoGit", targets: ["KujtoGit"]),
        .library(name: "KujtoSync", targets: ["KujtoSync"]),
        .library(name: "KujtoAuth", targets: ["KujtoAuth"]),
        .library(name: "KujtoStudioUI", targets: ["KujtoStudioUI"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.3.0")
    ],
    targets: [
        .target(
            name: "KujtoCore",
            path: "Sources/KujtoCore"
        ),
        .target(
            name: "KujtoGit",
            dependencies: ["KujtoCore"],
            path: "Sources/KujtoGit"
        ),
        .target(
            name: "KujtoSync",
            dependencies: ["KujtoCore", "KujtoGit"],
            path: "Sources/KujtoSync"
        ),
        .target(
            name: "KujtoAuth",
            path: "Sources/KujtoAuth"
        ),
        .target(
            name: "KujtoStudioUI",
            dependencies: ["KujtoGit", "KujtoSync"],
            path: "Sources/KujtoStudioUI"
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
        ),
        .testTarget(
            name: "KujtoGitTests",
            dependencies: ["KujtoGit", "KujtoCore"],
            path: "Tests/KujtoGitTests"
        ),
        .testTarget(
            name: "KujtoSyncTests",
            dependencies: ["KujtoSync", "KujtoGit", "KujtoCore"],
            path: "Tests/KujtoSyncTests"
        ),
        .testTarget(
            name: "KujtoAuthTests",
            dependencies: ["KujtoAuth"],
            path: "Tests/KujtoAuthTests"
        ),
        .testTarget(
            name: "KujtoStudioUITests",
            dependencies: ["KujtoStudioUI", "KujtoGit", "KujtoSync"],
            path: "Tests/KujtoStudioUITests"
        )
    ]
)
