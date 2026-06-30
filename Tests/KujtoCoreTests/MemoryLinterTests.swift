import XCTest
@testable import KujtoCore

final class MemoryLinterTests: XCTestCase {
    private func makeRepo(withAgents: Bool = true, withMemoryIndex: Bool = true) throws -> URL {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("kujto-lint-\(UUID().uuidString)")
        let fm = FileManager.default
        try fm.createDirectory(at: root.appendingPathComponent("memory"), withIntermediateDirectories: true)
        try fm.createDirectory(at: root.appendingPathComponent("Sources/Home"), withIntermediateDirectories: true)
        if withAgents {
            try "# Agents".write(to: root.appendingPathComponent("AGENTS.md"), atomically: true, encoding: .utf8)
        }
        if withMemoryIndex {
            try "# Index".write(to: root.appendingPathComponent("memory/MEMORY.md"), atomically: true, encoding: .utf8)
        }
        try "import Foundation\nstruct HomeReducer {}".write(
            to: root.appendingPathComponent("Sources/Home/HomeReducer.swift"),
            atomically: true, encoding: .utf8
        )
        return root
    }

    func testCleanRepoReportsNoIssues() throws {
        let root = try makeRepo()
        defer { try? FileManager.default.removeItem(at: root) }
        try """
        ---
        applies_to:
          - "**/*Reducer.swift"
        ---
        # TCA
        body
        """.write(to: root.appendingPathComponent("memory/tca.md"), atomically: true, encoding: .utf8)

        XCTAssertTrue(try MemoryLinter.lint(root: root).isEmpty)
    }

    func testFlagsMissingGovernanceFiles() throws {
        let root = try makeRepo(withAgents: false, withMemoryIndex: false)
        defer { try? FileManager.default.removeItem(at: root) }
        let issues = try MemoryLinter.lint(root: root)
        XCTAssertTrue(issues.contains { $0.code == "missing_agents_file" && $0.severity == .error })
        XCTAssertTrue(issues.contains { $0.code == "missing_memory_index" && $0.severity == .warning })
    }

    func testFlagsUnmatchedGlob() throws {
        let root = try makeRepo()
        defer { try? FileManager.default.removeItem(at: root) }
        try """
        ---
        applies_to:
          - "**/*Coordinator.swift"
        ---
        # Nav
        body
        """.write(to: root.appendingPathComponent("memory/nav.md"), atomically: true, encoding: .utf8)

        let issues = try MemoryLinter.lint(root: root)
        XCTAssertTrue(issues.contains { $0.code == "unmatched_glob" && $0.file == "memory/nav.md" })
    }

    func testFlagsBrokenWikiLink() throws {
        let root = try makeRepo()
        defer { try? FileManager.default.removeItem(at: root) }
        try """
        # TCA
        See [[ghost_doc]] for context.
        """.write(to: root.appendingPathComponent("memory/tca.md"), atomically: true, encoding: .utf8)

        let issues = try MemoryLinter.lint(root: root)
        XCTAssertTrue(issues.contains { $0.code == "broken_link" && $0.message.contains("ghost_doc") })
    }

    func testWikiLinkToSiblingSlugIsValid() throws {
        let root = try makeRepo()
        defer { try? FileManager.default.removeItem(at: root) }
        try "# Sibling\n".write(to: root.appendingPathComponent("memory/sibling.md"), atomically: true, encoding: .utf8)
        try "# TCA\nSee [[sibling]] for context.".write(
            to: root.appendingPathComponent("memory/tca.md"),
            atomically: true, encoding: .utf8
        )

        let issues = try MemoryLinter.lint(root: root)
        XCTAssertFalse(issues.contains { $0.code == "broken_link" })
    }
}
