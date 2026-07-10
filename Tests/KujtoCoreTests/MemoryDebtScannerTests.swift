import XCTest
@testable import KujtoCore

final class MemoryDebtScannerTests: XCTestCase {

    // MARK: - Pure scoring

    func testCleanRepoIsHealthyZero() {
        let debt = MemoryDebtScanner.score(lintErrors: 0, lintWarnings: 0, conflicts: 0, staleRules: 0, overrides: 0)
        XCTAssertEqual(debt.score, 0)
        XCTAssertEqual(debt.grade, .healthy)
        XCTAssertTrue(debt.components.isEmpty)
        XCTAssertTrue(debt.summary.contains("Healthy"))
    }

    func testEveryComponentIsExplained() {
        let debt = MemoryDebtScanner.score(lintErrors: 1, lintWarnings: 2, conflicts: 1, staleRules: 1, overrides: 1)
        // 10 + 6 + 8 + 4 + 5 = 33
        XCTAssertEqual(debt.score, 33)
        XCTAssertEqual(debt.grade, .watch)
        XCTAssertEqual(debt.components.count, 5)
        XCTAssertEqual(debt.components.map { $0.points }, [10, 6, 8, 4, 5])
        // Only non-zero inputs appear (the "explains its inputs" contract).
        XCTAssertTrue(debt.components.allSatisfy { $0.count > 0 })
    }

    func testZeroCountsAreOmitted() {
        let debt = MemoryDebtScanner.score(lintErrors: 0, lintWarnings: 0, conflicts: 2, staleRules: 0, overrides: 0)
        XCTAssertEqual(debt.components.count, 1)
        XCTAssertEqual(debt.components[0].name, "Conflicts")
        XCTAssertEqual(debt.score, 16)
    }

    func testHeavyGradeAndClamp() {
        let debt = MemoryDebtScanner.score(lintErrors: 20, lintWarnings: 0, conflicts: 0, staleRules: 0, overrides: 0)
        XCTAssertEqual(debt.score, 100)   // clamped
        XCTAssertEqual(debt.grade, .heavy)
    }

    func testGradeThresholds() {
        XCTAssertEqual(MemoryDebtScanner.score(lintErrors: 0, lintWarnings: 6, conflicts: 0, staleRules: 0, overrides: 0).grade, .healthy) // 18
        XCTAssertEqual(MemoryDebtScanner.score(lintErrors: 2, lintWarnings: 0, conflicts: 0, staleRules: 0, overrides: 0).grade, .watch)   // 20
        XCTAssertEqual(MemoryDebtScanner.score(lintErrors: 5, lintWarnings: 0, conflicts: 0, staleRules: 0, overrides: 0).grade, .heavy)   // 50
    }

    // MARK: - Date parsing / staleness

    func testParsesGitShortDate() {
        XCTAssertNotNil(MemoryDebtScanner.parseDate("2026-07-01"))
        XCTAssertNil(MemoryDebtScanner.parseDate("not-a-date"))
    }

    // MARK: - Integration

    func testAssessCountsStaleRule() throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("kujto-debt-\(UUID().uuidString)")
        let fm = FileManager.default
        try fm.createDirectory(at: root.appendingPathComponent("memory"), withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }

        let runner = ProcessRunner()
        try XCTSkipUnless((try? runner.run("git", arguments: ["-C", root.path, "init"]))?.exitCode == 0,
                          "git not available")

        try "# Kujto".write(to: root.appendingPathComponent("AGENTS.md"), atomically: true, encoding: .utf8)
        try "# Index".write(to: root.appendingPathComponent("memory/MEMORY.md"), atomically: true, encoding: .utf8)
        try "# Old rule".write(to: root.appendingPathComponent("memory/old.md"), atomically: true, encoding: .utf8)
        _ = try runner.run("git", arguments: ["-C", root.path, "add", "-A"])
        _ = try runner.run("git", arguments: ["-C", root.path, "-c", "user.email=t@t.dev",
                                              "-c", "user.name=t",
                                              "-c", "commit.gpgsign=false",
                                              "commit", "--date=2020-01-01T00:00:00", "-m", "old commit"])

        // With "now" far in the future, the 2020 commit is well past the window.
        let future = Date(timeIntervalSince1970: 1_900_000_000) // year ~2030
        let debt = try MemoryDebtScanner.assess(root: root, staleDays: 180, now: future)
        XCTAssertTrue(debt.components.contains { $0.name == "Stale rules" && $0.count >= 1 })
    }
}
