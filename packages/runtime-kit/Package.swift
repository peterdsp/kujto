// swift-tools-version:5.9
import PackageDescription

// KujtoRuntimeKit
//
// Optional debug SDK that host iOS/macOS apps embed to expose structured
// runtime state to Kujto Studio. The kit binds a small HTTP endpoint on
// 127.0.0.1 that Kujto queries from the macOS host. Debug-only; ships as
// a wrapping no-op in Release.
//
// Kujto never scrapes production data. The kit's providers are user
// controlled - you decide what to expose, and there's a hard deny-list
// for anything that looks like a token / secret / keychain payload.
let package = Package(
    name: "KujtoRuntimeKit",
    platforms: [.iOS(.v15), .macOS(.v13)],
    products: [
        .library(name: "KujtoRuntimeKit", targets: ["KujtoRuntimeKit"]),
    ],
    dependencies: [],
    targets: [
        .target(name: "KujtoRuntimeKit"),
        .testTarget(name: "KujtoRuntimeKitTests", dependencies: ["KujtoRuntimeKit"]),
    ]
)
