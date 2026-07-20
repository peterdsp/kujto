import XCTest
@testable import KujtoGit
import KujtoCore

/// `changedFiles(inCommit:)` powers the commit-to-rules direction of the
/// history cross-link. It must handle both ordinary commits and the root
/// commit (which has no parent).
final class ChangedFilesTests: XCTestCase {
    private let client = ShellGitClient()
    private var scratch: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        scratch = FileManager.default.temporaryDirectory
            .appendingPathComponent("kujtogit-changed-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let scratch = scratch { try? FileManager.default.removeItem(at: scratch) }
        try super.tearDownWithError()
    }

    @discardableResult
    private func git(_ args: [String], in repo: URL) throws -> String {
        let result = try ProcessRunner().run("git", arguments: ["-C", repo.path] + args)
        XCTAssertEqual(result.exitCode, 0, "git \(args.joined(separator: " ")): \(result.stderr)")
        return result.stdout
    }

    private func makeRepo() throws -> URL {
        let repo = scratch.appendingPathComponent("repo")
        try FileManager.default.createDirectory(at: repo, withIntermediateDirectories: true)
        try git(["init", "-b", "main"], in: repo)
        try git(["config", "user.name", "T"], in: repo)
        try git(["config", "user.email", "t@x"], in: repo)
        try git(["config", "commit.gpgsign", "false"], in: repo)
        return repo
    }

    private func write(_ text: String, _ file: String, in repo: URL) throws {
        let url = repo.appendingPathComponent(file)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try text.write(to: url, atomically: true, encoding: .utf8)
    }

    func testRootCommitFilesAreListed() throws {
        let repo = try makeRepo()
        try write("a", "memory/a.md", in: repo)
        try write("b", "memory/b.md", in: repo)
        try git(["add", "-A"], in: repo)
        try git(["commit", "-m", "root"], in: repo)

        let files = try client.changedFiles(inCommit: "HEAD", in: repo)
        XCTAssertEqual(Set(files), ["memory/a.md", "memory/b.md"])
    }

    func testLaterCommitListsOnlyItsFiles() throws {
        let repo = try makeRepo()
        try write("a", "memory/a.md", in: repo)
        try git(["add", "-A"], in: repo)
        try git(["commit", "-m", "first"], in: repo)

        try write("changed", "memory/a.md", in: repo)
        try write("new", "skills/s.md", in: repo)
        try git(["add", "-A"], in: repo)
        try git(["commit", "-m", "second"], in: repo)

        let files = try client.changedFiles(inCommit: "HEAD", in: repo)
        XCTAssertEqual(Set(files), ["memory/a.md", "skills/s.md"])
    }
}
