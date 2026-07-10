import XCTest
@testable import KujtoCore

final class GitDiffTests: XCTestCase {

    // MARK: - Porcelain parsing

    func testParsesModifiedAndStaged() {
        let output = """
         M Sources/App.swift
        M  Sources/Staged.swift
        """
        XCTAssertEqual(GitDiff.parsePorcelain(output).sorted(),
                       ["Sources/App.swift", "Sources/Staged.swift"])
    }

    func testParsesUntracked() {
        let output = "?? New/File.swift"
        XCTAssertEqual(GitDiff.parsePorcelain(output), ["New/File.swift"])
    }

    func testRenameKeepsNewPath() {
        let output = "R  Old/Name.swift -> New/Name.swift"
        XCTAssertEqual(GitDiff.parsePorcelain(output), ["New/Name.swift"])
    }

    func testStripsQuotedPath() {
        let output = "?? \"weird name.swift\""
        XCTAssertEqual(GitDiff.parsePorcelain(output), ["weird name.swift"])
    }

    func testEmptyOutputIsNoFiles() {
        XCTAssertTrue(GitDiff.parsePorcelain("").isEmpty)
        XCTAssertTrue(GitDiff.parsePorcelain("\n\n").isEmpty)
    }

    // MARK: - Non-git directory

    func testNonGitDirectoryReportsNothing() throws {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("kujto-nogit-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        XCTAssertTrue(GitDiff.changedFiles(in: dir).isEmpty)
    }

    // MARK: - Real git repo

    func testDetectsUntrackedFileInRealRepo() throws {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("kujto-git-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let runner = ProcessRunner()
        let initResult = try runner.run("git", arguments: ["-C", dir.path, "init"])
        try XCTSkipUnless(initResult.exitCode == 0, "git not available")

        try "changed".write(to: dir.appendingPathComponent("Touched.swift"),
                            atomically: true, encoding: .utf8)
        let changed = GitDiff.changedFiles(in: dir)
        XCTAssertTrue(changed.contains("Touched.swift"))
    }
}
