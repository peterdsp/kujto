// swift-tools-version:5.3
import PackageDescription

let package = Package(
    name: "kujto",
    platforms: [
        .macOS(.v10_15)
    ],
    products: [
        .executable(name: "kujto", targets: ["KujtoCLI"])
    ],
    targets: [
        .target(name: "KujtoCLI")
    ]
)
