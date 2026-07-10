import XCTest
@testable import KujtoCore

final class RiskScorerTests: XCTestCase {

    // MARK: - Builders

    private func rule(_ path: String, risk: [String] = []) -> Rule {
        Rule(path: path, title: (path as NSString).lastPathComponent, appliesTo: ["**/*.swift"], risk: risk, kind: .memory)
    }

    private func match(_ rule: Rule, glob: String = "**/*.swift", score: Int = 10) -> RuleMatch {
        RuleMatch(rule: rule, glob: glob, score: score)
    }

    // MARK: - Levels

    func testNoSignalsIsSafeWithZeroScore() {
        let s = RiskScorer.score(.init(path: "A.swift", matches: []))
        XCTAssertEqual(s.level, .safe)
        XCTAssertEqual(s.score, 0)
        XCTAssertEqual(s.action, .proceed)
        XCTAssertTrue(s.causes.isEmpty)
    }

    func testSingleScopedRuleIsWatch() {
        let s = RiskScorer.score(.init(path: "A.swift", matches: [match(rule("m/a.md"))]))
        XCTAssertEqual(s.level, .watch)
        XCTAssertEqual(s.action, .reviewContext)
    }

    func testRiskRuleAloneIsWatch() {
        let s = RiskScorer.score(.init(path: "A.swift", matches: [match(rule("m/pay.md", risk: ["payment"]))],
                                       relatedTestCount: 1))
        XCTAssertEqual(s.level, .watch)
        XCTAssertTrue(s.headline.contains("payment"))
    }

    func testRiskRuleWhileDirtyEscalates() {
        let s = RiskScorer.score(.init(path: "A.swift",
                                       matches: [match(rule("m/pay.md", risk: ["payment"]))],
                                       relatedTestCount: 1,
                                       isDirty: true))
        XCTAssertEqual(s.level, .escalating)
        XCTAssertTrue(s.causes.contains { $0.title == "Unsaved changes" })
    }

    func testRiskyUntestedConflictedDirtyFileIsBlocked() {
        let r = rule("m/pay.md", risk: ["payment"])
        let conflict = Conflict(kind: .overlappingScope, first: r, second: rule("m/other.md"),
                                summary: "overlap")
        let s = RiskScorer.score(.init(path: "A.swift",
                                       matches: [match(r)],
                                       conflicts: [conflict],
                                       relatedTestCount: 0,
                                       isDirty: true))
        XCTAssertEqual(s.level, .blocked)
        XCTAssertEqual(s.action, .addOverrideReason)
    }

    // MARK: - Cause behavior

    func testDirtyBoostSkippedWhenNoOtherRisk() {
        let s = RiskScorer.score(.init(path: "A.swift", matches: [], isDirty: true))
        XCTAssertEqual(s.level, .safe)
        XCTAssertFalse(s.causes.contains { $0.title == "Unsaved changes" })
    }

    func testUntestedCauseOnlyForRiskRules() {
        // A plain scoped rule with no tests must NOT add the untested-risk cause.
        let s = RiskScorer.score(.init(path: "A.swift", matches: [match(rule("m/a.md"))],
                                       relatedTestCount: 0))
        XCTAssertFalse(s.causes.contains { $0.title == "No related tests" })
    }

    func testConflictActionWinsOverContext() {
        let r = rule("m/pay.md", risk: ["payment"])
        let conflict = Conflict(kind: .duplicateTitle, first: r, second: rule("m/b.md"), summary: "dup")
        let s = RiskScorer.score(.init(path: "A.swift", matches: [match(r)],
                                       conflicts: [conflict], relatedTestCount: 5))
        XCTAssertEqual(s.action, .resolveConflicts)
    }

    func testDuplicateConflictCountedOnce() {
        let r = rule("m/pay.md", risk: ["payment"])
        let c = Conflict(kind: .duplicateTitle, first: r, second: rule("m/b.md"), summary: "same")
        let s = RiskScorer.score(.init(path: "A.swift", matches: [match(r)],
                                       conflicts: [c, c], relatedTestCount: 5))
        XCTAssertEqual(s.causes.filter { $0.title == "Conflict" }.count, 1)
    }

    func testCausesRankedByWeightDescending() {
        let s = RiskScorer.score(.init(path: "A.swift",
                                       matches: [match(rule("m/a.md")), match(rule("m/pay.md", risk: ["auth"]))],
                                       relatedTestCount: 1))
        let weights = s.causes.map { $0.weight }
        XCTAssertEqual(weights, weights.sorted(by: >))
    }

    // MARK: - Aggregation

    func testAggregateTakesWorstFile() {
        let calm = RiskScorer.score(.init(path: "A.swift", matches: [match(rule("m/a.md"))]))
        let hot = RiskScorer.score(.init(path: "B.swift",
                                         matches: [match(rule("m/pay.md", risk: ["payment"]))],
                                         relatedTestCount: 0, isDirty: true))
        let repo = RiskScorer.aggregate(files: [FileScore(path: "A.swift", score: calm),
                                                 FileScore(path: "B.swift", score: hot)])
        XCTAssertEqual(repo.score, hot.score)
        XCTAssertGreaterThanOrEqual(repo.level, hot.level)
    }

    func testRepoWideLintRaisesVerdict() {
        let clean = RiskScorer.aggregate(files: [], repoIssues: [])
        XCTAssertEqual(clean.level, .safe)

        let missing = LintIssue(severity: .error, code: "missing_agents_file", file: "AGENTS.md",
                                message: "AGENTS.md is missing.")
        let flagged = RiskScorer.aggregate(files: [], repoIssues: [missing])
        XCTAssertGreaterThan(flagged.level, .safe)
        XCTAssertTrue(flagged.causes.contains { $0.title.contains("missing_agents_file") })
    }

    func testLevelThresholds() {
        XCTAssertEqual(RiskScorer.level(for: 0), .safe)
        XCTAssertEqual(RiskScorer.level(for: 11), .safe)
        XCTAssertEqual(RiskScorer.level(for: 12), .watch)
        XCTAssertEqual(RiskScorer.level(for: 39), .watch)
        XCTAssertEqual(RiskScorer.level(for: 40), .escalating)
        XCTAssertEqual(RiskScorer.level(for: 74), .escalating)
        XCTAssertEqual(RiskScorer.level(for: 75), .blocked)
        XCTAssertEqual(RiskScorer.level(for: 100), .blocked)
    }

    // MARK: - End-to-end assess()

    func testAssessScoresARiskTaggedFile() throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("kujto-risk-\(UUID().uuidString)")
        let fm = FileManager.default
        try fm.createDirectory(at: root.appendingPathComponent("memory"), withIntermediateDirectories: true)
        try fm.createDirectory(at: root.appendingPathComponent("Sources"), withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }

        try "# Kujto".write(to: root.appendingPathComponent("AGENTS.md"), atomically: true, encoding: .utf8)
        try "# Index".write(to: root.appendingPathComponent("memory/MEMORY.md"), atomically: true, encoding: .utf8)
        try """
        ---
        applies_to:
          - "**/*Checkout*.swift"
        risk: payment
        ---
        # Checkout rules
        """.write(to: root.appendingPathComponent("memory/checkout.md"), atomically: true, encoding: .utf8)
        try "struct CheckoutView {}".write(
            to: root.appendingPathComponent("Sources/CheckoutView.swift"), atomically: true, encoding: .utf8)

        let result = try RiskScorer.assess(root: root, changedFiles: ["Sources/CheckoutView.swift"])
        XCTAssertGreaterThan(result.verdict.level, .safe)
        XCTAssertTrue(result.files.contains { $0.path == "Sources/CheckoutView.swift" })

        // The snapshot convenience carries the verdict and counts unchanged.
        let snapshot = RiskSnapshot(result, repoPath: root.path)
        XCTAssertEqual(snapshot.level, result.verdict.level)
        XCTAssertEqual(snapshot.score, result.verdict.score)
        XCTAssertEqual(snapshot.fileCount, result.files.count)

        // Recorded twice, the ledger exposes current and previous.
        let ledgerURL = root.appendingPathComponent(".kujto/ledger.json")
        let ledger = RuleEventLedger(fileURL: ledgerURL)
        try ledger.record(RiskSnapshot(result, repoPath: root.path,
                                       takenAt: Date(timeIntervalSince1970: 100)))
        try ledger.record(RiskSnapshot(result, repoPath: root.path,
                                       takenAt: Date(timeIntervalSince1970: 200)))
        XCTAssertNotNil(ledger.latestSnapshot(forRepo: root.path))
        XCTAssertNotNil(ledger.previousSnapshot(forRepo: root.path))
    }
}
