import XCTest
@testable import KujtoCore

final class RuleHistoryScannerTests: XCTestCase {

    private let sep = "\u{1f}"

    // MARK: - Log parsing

    func testParsesFields() {
        let line = ["abc123", "Jane Dev", "2026-07-01", "Add checkout rule"].joined(separator: sep)
        let parsed = RuleHistoryScanner.parseLog(line)
        XCTAssertEqual(parsed.count, 1)
        XCTAssertEqual(parsed[0].commit, "abc123")
        XCTAssertEqual(parsed[0].author, "Jane Dev")
        XCTAssertEqual(parsed[0].date, "2026-07-01")
        XCTAssertEqual(parsed[0].subject, "Add checkout rule")
    }

    func testSkipsMalformedLines() {
        let good = ["h", "a", "d", "s"].joined(separator: sep)
        let output = "not-enough-fields\n\(good)"
        XCTAssertEqual(RuleHistoryScanner.parseLog(output).count, 1)
    }

    // MARK: - Change points

    func testChangePointsDetectRiskShift() {
        let newer = RuleRevision(commit: "b", author: "x", date: "2026-07-02", subject: "tighten",
                                 risk: ["payment", "auth"], appliesTo: ["**/*.swift"])
        let older = RuleRevision(commit: "a", author: "x", date: "2026-07-01", subject: "add",
                                 risk: ["payment"], appliesTo: ["**/*.swift"])
        let changes = RuleHistoryScanner.changePoints(in: [newer, older])
        XCTAssertEqual(changes.count, 1)
        XCTAssertEqual(changes[0].newer.commit, "b")
    }

    func testNoChangePointWhenStable() {
        let a = RuleRevision(commit: "b", author: "x", date: "2", subject: "s", risk: ["payment"], appliesTo: ["g"])
        let b = RuleRevision(commit: "a", author: "x", date: "1", subject: "s", risk: ["payment"], appliesTo: ["g"])
        XCTAssertTrue(RuleHistoryScanner.changePoints(in: [a, b]).isEmpty)
    }

    // MARK: - Real repo integration

    func testTracesRuleThroughCommits() throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("kujto-hist-\(UUID().uuidString)")
        let fm = FileManager.default
        try fm.createDirectory(at: root.appendingPathComponent("memory"), withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }

        let runner = ProcessRunner()
        try XCTSkipUnless((try? runner.run("git", arguments: ["-C", root.path, "init"]))?.exitCode == 0,
                          "git not available")
        func commit(_ msg: String) throws {
            _ = try runner.run("git", arguments: ["-C", root.path, "add", "-A"])
            _ = try runner.run("git", arguments: ["-C", root.path, "-c", "user.email=t@t.dev",
                                                  "-c", "user.name=Tester", "commit", "-m", msg])
        }

        let rule = root.appendingPathComponent("memory/checkout.md")
        try """
        ---
        applies_to:
          - "**/*Checkout*.swift"
        risk: payment
        ---
        # Checkout rules
        """.write(to: rule, atomically: true, encoding: .utf8)
        try commit("Add checkout rule")

        try """
        ---
        applies_to:
          - "**/*Checkout*.swift"
        risk: [payment, auth]
        ---
        # Checkout rules
        """.write(to: rule, atomically: true, encoding: .utf8)
        try commit("Tighten checkout risk")

        let history = RuleHistoryScanner.history(forRule: "memory/checkout.md", in: root)
        XCTAssertEqual(history.count, 2)
        // Newest first: the tightened risk revision leads.
        XCTAssertEqual(Set(history[0].risk), ["payment", "auth"])
        XCTAssertEqual(Set(history[1].risk), ["payment"])
        XCTAssertEqual(history[0].subject, "Tighten checkout risk")

        // The change is surfaced as a single risk change point.
        XCTAssertEqual(RuleHistoryScanner.changePoints(in: history).count, 1)
    }
}
