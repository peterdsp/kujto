import XCTest
@testable import KujtoStudioUI
import KujtoCore

/// The fusion's aggregation logic, over a synthetic in-memory RuleIndex and an
/// injected tests resolver so no repo or filesystem is needed. The matching
/// itself is RuleIndex's job and tested there; here we prove the per-commit
/// roll-up: verdict is the worst file, risk and tests are unioned.
final class CommitInspectorTests: XCTestCase {

    private func index() -> RuleIndex {
        RuleIndex(rules: [
            Rule(path: "memory/domains/ios/architectures/tca.md", title: "TCA",
                 appliesTo: ["**/*Reducer.swift"], risk: [], kind: .memory),
            Rule(path: "memory/domains/payments/audit.md", title: "Payment audit",
                 appliesTo: ["**/*PaymentClient.swift", "**/Checkout*/**"], risk: ["payment"], kind: .memory),
            Rule(path: "memory/core/style.md", title: "Style",
                 appliesTo: [], risk: [], kind: .memory) // base memory, never file-scoped
        ])
    }

    func testDangerZoneFileGetsRiskTagsAndVerdict() {
        let inspector = CommitInspector(index: index(), testsResolver: { _ in [] })
        let result = inspector.inspect(paths: ["App/PaymentClient.swift"])

        XCTAssertEqual(result.verdict, .dangerZone)
        XCTAssertEqual(result.riskTags, ["payment"])
        let file = result.files.first
        XCTAssertEqual(file?.confidence, .dangerZone)
        XCTAssertEqual(file?.risk, ["payment"])
        XCTAssertFalse(file?.rules.isEmpty ?? true)
    }

    func testMatchWithoutRiskNeedsContext() {
        let inspector = CommitInspector(index: index(), testsResolver: { _ in [] })
        let result = inspector.inspect(paths: ["App/HomeReducer.swift"])
        XCTAssertEqual(result.verdict, .needsContext)
        XCTAssertTrue(result.riskTags.isEmpty)
    }

    func testUnmatchedFileIsSafe() {
        let inspector = CommitInspector(index: index(), testsResolver: { _ in [] })
        let result = inspector.inspect(paths: ["README.md"])
        XCTAssertEqual(result.verdict, .safe)
        XCTAssertTrue(result.files.first?.rules.isEmpty ?? false)
    }

    func testAggregateVerdictIsWorstOfFiles() {
        let inspector = CommitInspector(index: index(), testsResolver: { _ in [] })
        // A safe file, a needs-context file, and a danger-zone file together.
        let result = inspector.inspect(paths: [
            "README.md", "App/HomeReducer.swift", "App/PaymentClient.swift"
        ])
        XCTAssertEqual(result.verdict, .dangerZone, "worst file wins the banner")
        XCTAssertEqual(result.riskTags, ["payment"])
    }

    func testTestsAreUnionedAndSorted() {
        let inspector = CommitInspector(index: index(), testsResolver: { path in
            path.hasSuffix("PaymentClient.swift") ? ["PaymentClientTests.swift", "PaymentTests.swift"]
                                                  : ["HomeReducerTests.swift"]
        })
        let result = inspector.inspect(paths: ["App/PaymentClient.swift", "App/HomeReducer.swift"])
        XCTAssertEqual(result.testsToRun,
                       ["HomeReducerTests.swift", "PaymentClientTests.swift", "PaymentTests.swift"])
    }

    func testEmptyWhenNothingStaged() {
        let inspector = CommitInspector(index: index(), testsResolver: { _ in [] })
        XCTAssertTrue(inspector.inspect(paths: []).isEmpty)
    }
}
