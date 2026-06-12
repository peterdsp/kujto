import XCTest
@testable import KujtoCore

final class ExitCodeTests: XCTestCase {
    func testLogicalFailuresMapToOne() {
        XCTAssertEqual(ExitCode.forKujtoError(.buildFailed), 1)
        XCTAssertEqual(ExitCode.forKujtoError(.testFailed), 1)
        XCTAssertEqual(ExitCode.forKujtoError(.uiAssertionFailed), 1)
        XCTAssertEqual(ExitCode.forKujtoError(.signingFailed), 1)
        XCTAssertEqual(ExitCode.forKujtoError(.deviceLocked), 1)
    }

    func testUsageErrors() {
        XCTAssertEqual(ExitCode.forKujtoError(.unknownArgument), 2)
        XCTAssertEqual(ExitCode.forKujtoError(.refusedSelfWire), 2)
    }

    func testStableMappings() {
        XCTAssertEqual(ExitCode.forKujtoError(.timeout), 124)
        XCTAssertEqual(ExitCode.forKujtoError(.notYetImplemented), 75)
        XCTAssertEqual(ExitCode.forKujtoError(.invalidConfig), 78)
        XCTAssertEqual(ExitCode.forKujtoError(.process), 70)
    }
}
