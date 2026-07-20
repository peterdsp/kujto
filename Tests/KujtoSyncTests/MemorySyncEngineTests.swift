import XCTest
@testable import KujtoSync
import KujtoGit
import KujtoCore

/// End-to-end sync-loop tests against real temp repos. These prove the
/// invisible round-trip the design promises: a change on one machine reaches
/// the other, a secret never commits, a same-line clash surfaces, and being
/// offline never loses a local commit.
final class MemorySyncEngineTests: XCTestCase {
    private let engine = MemorySyncEngine()
    private var scratch: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        scratch = FileManager.default.temporaryDirectory
            .appendingPathComponent("kujtosync-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let scratch = scratch { try? FileManager.default.removeItem(at: scratch) }
        try super.tearDownWithError()
    }

    // MARK: Setup helpers

    @discardableResult
    private func git(_ args: [String], in repo: URL, file: StaticString = #filePath, line: UInt = #line) throws -> String {
        let result = try ProcessRunner().run("git", arguments: ["-C", repo.path] + args)
        XCTAssertEqual(result.exitCode, 0, "git \(args.joined(separator: " ")): \(result.stderr)", file: file, line: line)
        return result.stdout
    }

    private func makeRepo(named name: String) throws -> URL {
        let repo = scratch.appendingPathComponent(name)
        try FileManager.default.createDirectory(at: repo, withIntermediateDirectories: true)
        try git(["init", "-b", "main"], in: repo)
        try git(["config", "user.name", "Test"], in: repo)
        try git(["config", "user.email", "test@kujto.dev"], in: repo)
        try git(["config", "commit.gpgsign", "false"], in: repo)
        return repo
    }

    private func makeBareRemote(named name: String) throws -> URL {
        let remote = scratch.appendingPathComponent(name)
        try FileManager.default.createDirectory(at: remote, withIntermediateDirectories: true)
        try git(["init", "--bare", "-b", "main"], in: remote)
        return remote
    }

    private func write(_ text: String, to file: String, in repo: URL) throws {
        let url = repo.appendingPathComponent(file)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try text.write(to: url, atomically: true, encoding: .utf8)
    }

    private func configure(_ repo: URL, name: String) throws {
        try git(["config", "user.name", name], in: repo)
        try git(["config", "user.email", "\(name.lowercased())@kujto.dev"], in: repo)
        try git(["config", "commit.gpgsign", "false"], in: repo)
    }

    // MARK: Tests

    func testCleanTreeNoRemoteIsClean() throws {
        let repo = try makeRepo(named: "clean")
        XCTAssertEqual(try engine.tick(in: repo), .clean)
    }

    func testDirtyTreeNoRemoteCommitsLocalOnly() throws {
        let repo = try makeRepo(named: "local")
        try write("# style\n", to: "core/style.md", in: repo)

        XCTAssertEqual(try engine.tick(in: repo), .localOnly)
        let client = ShellGitClient()
        XCTAssertTrue(try client.status(in: repo).isClean, "the change should be committed")
        XCTAssertEqual(try client.log(in: repo, maxCount: 1).first?.subject,
                       "memory: update core/style.md (1 file)")
    }

    func testDirtyTreeWithRemotePushes() throws {
        let remote = try makeBareRemote(named: "origin.git")
        let repo = try makeRepo(named: "pusher")
        try git(["remote", "add", "origin", remote.path], in: repo)
        // Seed an upstream so pull/push have a tracking branch.
        try write("seed\n", to: "seed.md", in: repo)
        try ShellGitClient().stage([], in: repo)
        _ = try ShellGitClient().commit(message: "seed", in: repo)
        try git(["push", "-u", "origin", "main"], in: repo)

        try write("# a new rule\n", to: "rules/new.md", in: repo)
        XCTAssertEqual(try engine.tick(in: repo), .pushed)

        // A fresh clone must see the pushed rule.
        let verify = scratch.appendingPathComponent("verify")
        try git(["clone", remote.path, verify.path], in: scratch)
        XCTAssertTrue(FileManager.default.fileExists(atPath: verify.appendingPathComponent("rules/new.md").path))
    }

    func testSecretBlocksCommit() throws {
        let repo = try makeRepo(named: "secret")
        try write("token: ghp_0123456789abcdefghijklmnopqrstuvwxyzABCD\n", to: "core/env.md", in: repo)

        let outcome = try engine.tick(in: repo)
        guard case let .blockedBySecret(hits) = outcome else {
            return XCTFail("expected blockedBySecret, got \(outcome)")
        }
        XCTAssertEqual(hits.first?.kind, "github-token")
        // Nothing was committed: the repo is still dirty, so the user can fix it.
        XCTAssertFalse(try ShellGitClient().status(in: repo).isClean)
    }

    /// Two machines edit the same line: the loop must report a conflict, never
    /// silently overwrite one side.
    func testSameLineClashSurfacesConflict() throws {
        let remote = try makeBareRemote(named: "origin2.git")
        let a = try makeRepo(named: "a")
        try git(["remote", "add", "origin", remote.path], in: a)
        try write("original rule\n", to: "rules/x.md", in: a)
        try ShellGitClient().stage([], in: a)
        _ = try ShellGitClient().commit(message: "seed", in: a)
        try git(["push", "-u", "origin", "main"], in: a)

        // B changes the same line and pushes.
        let b = scratch.appendingPathComponent("b")
        try git(["clone", remote.path, b.path], in: scratch)
        try configure(b, name: "B")
        try write("B version\n", to: "rules/x.md", in: b)
        XCTAssertEqual(try engine.tick(in: b), .pushed)

        // A changes the same line, then ticks: conflict.
        try write("A version\n", to: "rules/x.md", in: a)
        let outcome = try engine.tick(in: a)
        guard case let .conflict(files) = outcome else {
            return XCTFail("expected conflict, got \(outcome)")
        }
        XCTAssertTrue(files.contains("rules/x.md"))
    }

    /// Different files on two machines merge silently: the common case must be
    /// invisible, with both files present afterward.
    func testDifferentFilesMergeSilently() throws {
        let remote = try makeBareRemote(named: "origin3.git")
        let a = try makeRepo(named: "da")
        try git(["remote", "add", "origin", remote.path], in: a)
        try write("base\n", to: "base.md", in: a)
        try ShellGitClient().stage([], in: a)
        _ = try ShellGitClient().commit(message: "seed", in: a)
        try git(["push", "-u", "origin", "main"], in: a)

        let b = scratch.appendingPathComponent("db")
        try git(["clone", remote.path, b.path], in: scratch)
        try configure(b, name: "B")
        try write("b content\n", to: "from-b.md", in: b)
        XCTAssertEqual(try engine.tick(in: b), .pushed)

        try write("a content\n", to: "from-a.md", in: a)
        XCTAssertEqual(try engine.tick(in: a), .pushed)
        // A now has its own file and B's, merged with no conflict.
        XCTAssertTrue(FileManager.default.fileExists(atPath: a.appendingPathComponent("from-b.md").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: a.appendingPathComponent("from-a.md").path))
    }

    /// An unreachable remote must never lose the local commit.
    func testOfflineRemoteDefersPushKeepsCommit() throws {
        let repo = try makeRepo(named: "offline")
        // Point at a remote path that does not exist, but still register a
        // tracking branch by faking upstream config.
        let deadRemote = scratch.appendingPathComponent("does-not-exist.git")
        try git(["remote", "add", "origin", deadRemote.path], in: repo)
        try write("seed\n", to: "seed.md", in: repo)
        try ShellGitClient().stage([], in: repo)
        _ = try ShellGitClient().commit(message: "seed", in: repo)
        // Set upstream tracking without a reachable remote. Configuring the
        // tracking refs directly avoids needing an origin/main ref to exist.
        try git(["config", "branch.main.remote", "origin"], in: repo)
        try git(["config", "branch.main.merge", "refs/heads/main"], in: repo)

        try write("# offline edit\n", to: "rules/offline.md", in: repo)
        let outcome = try engine.tick(in: repo)
        XCTAssertEqual(outcome, .pushDeferred)
        // The commit is safe locally even though the push could not happen.
        XCTAssertTrue(try ShellGitClient().status(in: repo).isClean)
        XCTAssertEqual(try ShellGitClient().log(in: repo, maxCount: 1).first?.subject,
                       "memory: update rules/offline.md (1 file)")
    }
}
