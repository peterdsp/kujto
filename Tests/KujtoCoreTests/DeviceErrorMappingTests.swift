import XCTest
@testable import KujtoCore

final class DeviceErrorMappingTests: XCTestCase {
    private let controller = DeviceController()

    func testLockedDevice() {
        let err = controller.mapDeviceError(stderr: "Error: The device is locked. Unlock and retry.", fallback: .appInstallFailed)
        XCTAssertEqual(err.code, .deviceLocked)
    }

    func testUntrustedHost() {
        let err = controller.mapDeviceError(stderr: "Device not trusted. Please trust this computer.", fallback: .appInstallFailed)
        XCTAssertEqual(err.code, .deviceNotTrusted)
    }

    func testProvisioningProfile() {
        let err = controller.mapDeviceError(stderr: "No matching provisioning profile found", fallback: .appInstallFailed)
        XCTAssertEqual(err.code, .provisioningFailed)
    }

    func testNoDevelopmentTeam() {
        let err = controller.mapDeviceError(stderr: "No development team specified", fallback: .appInstallFailed)
        XCTAssertEqual(err.code, .noDevelopmentTeam)
    }

    func testIncompatibleOS() {
        let err = controller.mapDeviceError(stderr: "The app's MinimumOSVersion is higher than the device's OS", fallback: .appLaunchFailed)
        XCTAssertEqual(err.code, .deviceIncompatible)
    }

    func testFallbackKeepsCode() {
        let err = controller.mapDeviceError(stderr: "kaboom kapow", fallback: .appLaunchFailed)
        XCTAssertEqual(err.code, .appLaunchFailed)
    }
}
