import XCTest
@testable import KujtoCore

final class ConfigMergeTests: XCTestCase {
    func testLocalOverridesShared() {
        let shared = KujtoConfig(workspace: "App.xcworkspace", scheme: "App", configuration: "Debug")
        let local = KujtoConfig(scheme: "AppPro", simulatorName: "iPhone 16")
        let merged = shared.merging(local)
        XCTAssertEqual(merged.workspace, "App.xcworkspace")
        XCTAssertEqual(merged.scheme, "AppPro")
        XCTAssertEqual(merged.configuration, "Debug")
        XCTAssertEqual(merged.simulatorName, "iPhone 16")
    }

    func testNilLocalKeepsShared() {
        let shared = KujtoConfig(scheme: "App")
        let local = KujtoConfig()
        XCTAssertEqual(shared.merging(local).scheme, "App")
    }
}
