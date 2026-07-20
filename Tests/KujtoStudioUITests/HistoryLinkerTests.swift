import XCTest
@testable import KujtoStudioUI
import KujtoCore
import KujtoGit

/// The cross-link both ways: a commit maps to the rules it touched (via the
/// fake client's changed files), and a rule maps to its revisions (via
/// RuleHistoryScanner over a real repo).
final class HistoryLinkerTests: XCTestCase {

    private func index() -> RuleIndex {
        RuleIndex(rules: [
            Rule(path: "memory/domains/payments/audit.md", title: "Payment audit",
                 appliesTo: ["**/*PaymentClient.swift"], risk: ["payment"], kind: .memory),
            Rule(path: "memory/domains/ios/tca.md", title: "TCA",
                 appliesTo: ["**/*Reducer.swift"], risk: [], kind: .memory)
        ])
    }

    func testRulesInCommitIntersectsChangedFiles() {
        let client = FakeGitClient(status: GitStatus(branch: "main", upstream: nil, ahead: 0, behind: 0, changes: []))
        client.changedFilesByCommit["abc"] = ["memory/domains/payments/audit.md", "src/App.swift"]

        let linker = HistoryLinker(client: client, index: index(), root: URL(fileURLWithPath: "/tmp/x"))
        let rules = linker.rules(inCommit: "abc")

        XCTAssertEqual(rules.map { $0.path }, ["memory/domains/payments/audit.md"])
        XCTAssertTrue(linker.touchesRules("abc"))
    }

    func testCommitTouchingNoRuleIsEmpty() {
        let client = FakeGitClient(status: GitStatus(branch: "main", upstream: nil, ahead: 0, behind: 0, changes: []))
        client.changedFilesByCommit["def"] = ["src/App.swift", "README.md"]

        let linker = HistoryLinker(client: client, index: index(), root: URL(fileURLWithPath: "/tmp/x"))
        XCTAssertTrue(linker.rules(inCommit: "def").isEmpty)
        XCTAssertFalse(linker.touchesRules("def"))
    }

    func testRevisionsForRuleReadRealHistory() throws {
        // A real repo whose rule file changes twice; revisions should reflect
        // both commits, newest first.
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("kujto-hist-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        func git(_ args: [String]) throws {
            let r = try ProcessRunner().run("git", arguments: ["-C", root.path] + args)
            XCTAssertEqual(r.exitCode, 0, r.stderr)
        }
        func write(_ text: String) throws {
            let url = root.appendingPathComponent("memory/rule.md")
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try text.write(to: url, atomically: true, encoding: .utf8)
        }

        try git(["init", "-b", "main"])
        try git(["config", "user.name", "T"])
        try git(["config", "user.email", "t@x"])
        try git(["config", "commit.gpgsign", "false"])
        try write("---\nrisk: []\n---\n# Rule\n")
        try git(["add", "-A"]); try git(["commit", "-m", "add rule"])
        try write("---\nrisk: [payment]\n---\n# Rule\n")
        try git(["add", "-A"]); try git(["commit", "-m", "mark payment risk"])

        let linker = HistoryLinker(client: ShellGitClient(), index: index(), root: root)
        let revisions = linker.revisions(forRule: "memory/rule.md")

        XCTAssertEqual(revisions.count, 2)
        XCTAssertEqual(revisions.first?.subject, "mark payment risk")
        XCTAssertEqual(revisions.first?.risk, ["payment"], "newest revision reflects the risk drift")
    }
}
