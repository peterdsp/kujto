import XCTest
@testable import KujtoCore

final class AgentSandboxTests: XCTestCase {

    /// Builds a temp repo with a risk-tagged rule over Checkout files and a
    /// matching source file. `withTests` adds a sibling test.
    private func makeRepo(withTests: Bool) throws -> URL {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("kujto-preflight-\(UUID().uuidString)")
        let fm = FileManager.default
        try fm.createDirectory(at: root.appendingPathComponent("memory"), withIntermediateDirectories: true)
        try fm.createDirectory(at: root.appendingPathComponent("Sources"), withIntermediateDirectories: true)

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
        if withTests {
            try fm.createDirectory(at: root.appendingPathComponent("Tests"), withIntermediateDirectories: true)
            try "final class CheckoutTests {}".write(
                to: root.appendingPathComponent("Tests/CheckoutTests.swift"), atomically: true, encoding: .utf8)
        }
        return root
    }

    // MARK: - Readiness

    func testRiskyUntestedFileNeedsContext() throws {
        let root = try makeRepo(withTests: false)
        defer { try? FileManager.default.removeItem(at: root) }

        let pf = try AgentSandbox.preflight(file: "Sources/CheckoutView.swift", in: root)
        XCTAssertEqual(pf.readiness, .needsContext)
        XCTAssertTrue(pf.missingContext.contains { $0.contains("no sibling tests") })
        XCTAssertLessThan(pf.readinessScore, 100)
    }

    func testTestsRemoveTheUntestedGap() throws {
        let root = try makeRepo(withTests: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let pf = try AgentSandbox.preflight(file: "Sources/CheckoutView.swift", in: root)
        XCTAssertFalse(pf.missingContext.contains { $0.contains("no sibling tests") })
        XCTAssertFalse(pf.suggestedTests.isEmpty)
    }

    func testUnmatchedFileReportsNoScopedRules() throws {
        let root = try makeRepo(withTests: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let pf = try AgentSandbox.preflight(file: "Sources/Unrelated.swift", in: root)
        XCTAssertTrue(pf.matchedRulePaths.isEmpty)
        XCTAssertTrue(pf.missingContext.contains { $0.contains("only base memory") })
    }

    func testReadinessMapping() {
        XCTAssertEqual(AgentSandbox.readiness(for: .safe, gaps: []), .ready)
        XCTAssertEqual(AgentSandbox.readiness(for: .safe, gaps: ["x"]), .needsContext)
        XCTAssertEqual(AgentSandbox.readiness(for: .watch, gaps: []), .needsContext)
        XCTAssertEqual(AgentSandbox.readiness(for: .blocked, gaps: []), .blocked)
    }

    // MARK: - Prompt assembly

    func testPromptMentionsFileRiskAndReviewGate() throws {
        let root = try makeRepo(withTests: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let pf = try AgentSandbox.preflight(file: "Sources/CheckoutView.swift", in: root)
        XCTAssertTrue(pf.prompt.contains("Sources/CheckoutView.swift"))
        XCTAssertTrue(pf.prompt.contains("Checkout rules"))
        XCTAssertTrue(pf.prompt.contains("payment"))
        XCTAssertTrue(pf.prompt.contains("human reviews the diff"))
    }

    func testPromptIsDeterministic() throws {
        let root = try makeRepo(withTests: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let a = try AgentSandbox.preflight(file: "Sources/CheckoutView.swift", in: root)
        let b = try AgentSandbox.preflight(file: "Sources/CheckoutView.swift", in: root)
        XCTAssertEqual(a.prompt, b.prompt)
    }

    // MARK: - Sandbox worktree

    func testSandboxWorktreeRoundTripAppliesNothing() throws {
        let root = try makeRepo(withTests: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let runner = ProcessRunner()

        try XCTSkipUnless((try? runner.run("git", arguments: ["-C", root.path, "init"]))?.exitCode == 0,
                          "git not available")
        _ = try? runner.run("git", arguments: ["-C", root.path, "add", "-A"])
        _ = try? runner.run("git", arguments: ["-C", root.path, "-c", "user.email=t@t.dev",
                                               "-c", "user.name=t", "commit", "-m", "init"])

        let sandbox = try AgentSandbox.makeSandbox(in: root, name: "checkout")
        XCTAssertTrue(FileManager.default.fileExists(atPath: sandbox.path.path))
        // The real tree is untouched; edits would live only in the worktree.
        XCTAssertTrue(sandbox.remove())
        XCTAssertFalse(FileManager.default.fileExists(atPath: sandbox.path.path))
    }
}
