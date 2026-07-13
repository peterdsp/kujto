import XCTest
@testable import KujtoCore

final class SimctlArgsTests: XCTestCase {

    func testAppearance() {
        XCTAssertEqual(SimctlArgs.appearance(udid: "U1", style: "dark"),
                       ["simctl", "ui", "U1", "appearance", "dark"])
    }

    func testLocationSetFormatsCoordinates() {
        XCTAssertEqual(SimctlArgs.locationSet(udid: "U1", latitude: 37.7749, longitude: -122.4194),
                       ["simctl", "location", "U1", "set", "37.7749,-122.4194"])
    }

    func testLocationClearAndRun() {
        XCTAssertEqual(SimctlArgs.locationClear(udid: "U1"), ["simctl", "location", "U1", "clear"])
        XCTAssertEqual(SimctlArgs.locationRun(udid: "U1", scenario: "City Run"),
                       ["simctl", "location", "U1", "run", "City Run"])
    }

    func testStatusBarOverrideOnlyIncludesSetFlags() {
        let args = SimctlArgs.statusBarOverride(udid: "U1", time: "9:41", wifiBars: 3, batteryLevel: 100)
        XCTAssertEqual(args, [
            "simctl", "status_bar", "U1", "override",
            "--time", "9:41",
            "--wifiBars", "3",
            "--batteryLevel", "100"
        ])
    }

    func testStatusBarOverrideWithNoFlagsIsJustTheVerb() {
        // The CLI guards against this, but the builder itself stays honest.
        XCTAssertEqual(SimctlArgs.statusBarOverride(udid: "U1"),
                       ["simctl", "status_bar", "U1", "override"])
    }

    func testStatusBarClear() {
        XCTAssertEqual(SimctlArgs.statusBarClear(udid: "U1"), ["simctl", "status_bar", "U1", "clear"])
    }

    func testPushOmitsEmptyBundleId() {
        XCTAssertEqual(SimctlArgs.push(udid: "U1", bundleId: nil, payloadPath: "p.json"),
                       ["simctl", "push", "U1", "p.json"])
        XCTAssertEqual(SimctlArgs.push(udid: "U1", bundleId: "", payloadPath: "p.json"),
                       ["simctl", "push", "U1", "p.json"])
        XCTAssertEqual(SimctlArgs.push(udid: "U1", bundleId: "com.x.app", payloadPath: "-"),
                       ["simctl", "push", "U1", "com.x.app", "-"])
    }

    func testPrivacyAppendsBundleIdWhenPresent() {
        XCTAssertEqual(SimctlArgs.privacy(udid: "U1", action: "grant", service: "photos", bundleId: "com.x.app"),
                       ["simctl", "privacy", "U1", "grant", "photos", "com.x.app"])
        XCTAssertEqual(SimctlArgs.privacy(udid: "U1", action: "reset", service: "all", bundleId: nil),
                       ["simctl", "privacy", "U1", "reset", "all"])
    }

    func testGetAppContainer() {
        XCTAssertEqual(SimctlArgs.getAppContainer(udid: "U1", bundleId: "com.x.app", kind: nil),
                       ["simctl", "get_app_container", "U1", "com.x.app"])
        XCTAssertEqual(SimctlArgs.getAppContainer(udid: "U1", bundleId: "com.x.app", kind: "data"),
                       ["simctl", "get_app_container", "U1", "com.x.app", "data"])
    }

    func testCreateAndDelete() {
        XCTAssertEqual(SimctlArgs.create(name: "Test", deviceType: "iPhone 16", runtime: nil),
                       ["simctl", "create", "Test", "iPhone 16"])
        XCTAssertEqual(SimctlArgs.create(name: "Test", deviceType: "iPhone 16", runtime: "iOS17.5"),
                       ["simctl", "create", "Test", "iPhone 16", "iOS17.5"])
        XCTAssertEqual(SimctlArgs.delete(target: "U1"), ["simctl", "delete", "U1"])
    }

    func testPasteboard() {
        XCTAssertEqual(SimctlArgs.pasteboardCopy(udid: "U1"), ["simctl", "pbcopy", "U1"])
        XCTAssertEqual(SimctlArgs.pasteboardPaste(udid: "U1"), ["simctl", "pbpaste", "U1"])
    }
}
