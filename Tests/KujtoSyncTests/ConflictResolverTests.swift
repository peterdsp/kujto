import XCTest
@testable import KujtoSync
import KujtoGit
import KujtoCore

/// The conflict resolver: pure marker rewriting, plus a real end-to-end
/// resolution of a stopped rebase so we know continuing the rebase actually
/// works, not just the text transform.
final class ConflictResolverTests: XCTestCase {

    private let conflicted = """
    intro line
    <<<<<<< HEAD
    remote wins
    =======
    local wins
    >>>>>>> abc123 (local commit)
    outro line
    """

    func testKeepBothRetainsBothBodies() {
        let out = ConflictResolver.resolveText(conflicted, .keepBoth)
        XCTAssertEqual(out, "intro line\nremote wins\nlocal wins\noutro line")
    }

    func testKeepRemoteKeepsHeadSide() {
        let out = ConflictResolver.resolveText(conflicted, .keepRemote)
        XCTAssertEqual(out, "intro line\nremote wins\noutro line")
    }

    func testKeepLocalKeepsIncomingSide() {
        let out = ConflictResolver.resolveText(conflicted, .keepLocal)
        XCTAssertEqual(out, "intro line\nlocal wins\noutro line")
    }

    func testMultipleHunks() {
        let text = """
        <<<<<<< HEAD
        r1
        =======
        l1
        >>>>>>> x
        middle
        <<<<<<< HEAD
        r2
        =======
        l2
        >>>>>>> x
        """
        XCTAssertEqual(ConflictResolver.resolveText(text, .keepBoth), "r1\nl1\nmiddle\nr2\nl2")
    }

    func testNoConflictUnchanged() {
        let text = "just\nnormal\nlines"
        XCTAssertEqual(ConflictResolver.resolveText(text, .keepBoth), text)
    }

    // MARK: Real rebase resolution

    func testResolveKeepBothOnRealConflictThenSyncs() throws {
        let scratch = FileManager.default.temporaryDirectory
            .appendingPathComponent("kujto-resolve-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: scratch) }

        func git(_ args: [String], in repo: URL) throws {
            let r = try ProcessRunner().run("git", arguments: ["-C", repo.path] + args)
            XCTAssertEqual(r.exitCode, 0, r.stderr)
        }
        func configure(_ repo: URL, _ name: String) throws {
            try git(["config", "user.name", name], in: repo)
            try git(["config", "user.email", "\(name)@x"], in: repo)
            try git(["config", "commit.gpgsign", "false"], in: repo)
        }
        func write(_ text: String, _ file: String, in repo: URL) throws {
            let url = repo.appendingPathComponent(file)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try text.write(to: url, atomically: true, encoding: .utf8)
        }

        // Bare remote seeded from A.
        let remote = scratch.appendingPathComponent("origin.git")
        try FileManager.default.createDirectory(at: remote, withIntermediateDirectories: true)
        try git(["init", "--bare", "-b", "main"], in: remote)

        let a = scratch.appendingPathComponent("a")
        try FileManager.default.createDirectory(at: a, withIntermediateDirectories: true)
        try git(["init", "-b", "main"], in: a)
        try configure(a, "A")
        try git(["remote", "add", "origin", remote.path], in: a)
        try write("original\n", "rule.md", in: a)
        let engine = MemorySyncEngine()
        _ = try engine.tick(in: a)  // commits and pushes (localOnly first)
        try git(["push", "-u", "origin", "main"], in: a)

        // B clones and changes the same line, pushes.
        let b = scratch.appendingPathComponent("b")
        try git(["clone", remote.path, b.path], in: scratch)
        try configure(b, "B")
        try write("from B\n", "rule.md", in: b)
        XCTAssertEqual(try engine.tick(in: b), .pushed)

        // A changes the same line and ticks: conflict.
        try write("from A\n", "rule.md", in: a)
        let outcome = try engine.tick(in: a)
        guard case let .conflict(files) = outcome else {
            return XCTFail("expected conflict, got \(outcome)")
        }

        // Resolve keeping both, then sync again: it should now push cleanly and
        // the file should carry both bodies.
        try ConflictResolver().resolve(.keepBoth, files: files, in: a)
        let after = try String(contentsOf: a.appendingPathComponent("rule.md"), encoding: .utf8)
        XCTAssertTrue(after.contains("from B"))
        XCTAssertTrue(after.contains("from A"))

        // Sync again to push the resolved commit, and the working tree is clean.
        _ = try engine.tick(in: a)
        XCTAssertTrue(try ShellGitClient().status(in: a).isClean)

        // A fresh clone of the remote must carry both bodies: nothing was lost.
        let verify = scratch.appendingPathComponent("verify")
        try git(["clone", remote.path, verify.path], in: scratch)
        let remoteContent = try String(contentsOf: verify.appendingPathComponent("rule.md"), encoding: .utf8)
        XCTAssertTrue(remoteContent.contains("from A"))
        XCTAssertTrue(remoteContent.contains("from B"))
    }
}
