import XCTest
@testable import KujtoCore

final class DoctorTests: XCTestCase {

    func testAllToolsPresentIsHealthy() {
        let checks = Doctor.evaluate(toolExists: { _ in true }, simulatorCount: 3)
        XCTAssertTrue(Doctor.isHealthy(checks))
        XCTAssertTrue(checks.allSatisfy { $0.ok })
    }

    func testMissingXcodebuildFailsCriticalCheck() {
        let checks = Doctor.evaluate(
            toolExists: { $0 != "xcodebuild" },
            simulatorCount: 1
        )
        XCTAssertFalse(Doctor.isHealthy(checks))
        let xcodebuild = checks.first { $0.name == "xcodebuild" }
        XCTAssertEqual(xcodebuild?.ok, false)
        XCTAssertEqual(xcodebuild?.critical, true)
    }

    func testNoSimulatorsIsWarningNotFailure() {
        let checks = Doctor.evaluate(toolExists: { _ in true }, simulatorCount: 0)
        // Still healthy: the simulators check is advisory, not critical.
        XCTAssertTrue(Doctor.isHealthy(checks))
        let sims = checks.first { $0.name == "simulators" }
        XCTAssertEqual(sims?.ok, false)
        XCTAssertEqual(sims?.critical, false)
    }

    func testMissingGitIsNonCritical() {
        let checks = Doctor.evaluate(toolExists: { $0 != "git" }, simulatorCount: 2)
        XCTAssertTrue(Doctor.isHealthy(checks))
        XCTAssertEqual(checks.first { $0.name == "git" }?.critical, false)
    }
}
