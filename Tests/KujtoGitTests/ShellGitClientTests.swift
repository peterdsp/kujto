import XCTest
@testable import KujtoGit
import KujtoCore

/// Integration tests: real temp repos, the real `git` binary, exercising the
/// six operations end to end. The push/pull and conflict tests de-risk the
/// `KujtoSync` loop early, since its whole job is commit -> rebase -> push.
final class ShellGitClientTests: XCTestCase {
    private let client = ShellGitClient()
    private var scratch: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        scratch = FileManager.default.temporaryDirectory
            .appendingPathComponent("kujtogit-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let scratch = scratch { try? FileManager.default.removeItem(at: scratch) }
        try super.tearDownWithError()
    }

    // MARK: Helpers

    /// Runs a raw git command for test setup and asserts success.
    @discardableResult
    private func git(_ args: [String], in repo: URL, file: StaticString = #filePath, line: UInt = #line) throws -> String {
        let result = try ProcessRunner().run("git", arguments: ["-C", repo.path] + args)
        XCTAssertEqual(result.exitCode, 0, "git \(args.joined(separator: " ")): \(result.stderr)", file: file, line: line)
        return result.stdout
    }

    /// Creates a git repo on branch `main` with a deterministic identity and no
    /// signing, so commits are reproducible across machines and CI.
    private func makeRepo(named name: String) throws -> URL {
        let repo = scratch.appendingPathComponent(name)
        try FileManager.default.createDirectory(at: repo, withIntermediateDirectories: true)
        try git(["init", "-b", "main"], in: repo)
        try git(["config", "user.name", "Test User"], in: repo)
        try git(["config", "user.email", "test@kujto.dev"], in: repo)
        try git(["config", "commit.gpgsign", "false"], in: repo)
        return repo
    }

    private func write(_ text: String, to file: String, in repo: URL) throws {
        let url = repo.appendingPathComponent(file)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try text.write(to: url, atomically: true, encoding: .utf8)
    }

    // MARK: Tests

    func testIsRepositoryDetection() throws {
        let repo = try makeRepo(named: "detect")
        XCTAssertTrue(client.isRepository(repo))

        let plain = scratch.appendingPathComponent("not-a-repo")
        try FileManager.default.createDirectory(at: plain, withIntermediateDirectories: true)
        XCTAssertFalse(client.isRepository(plain))
    }

    func testStatusReportsUntrackedAndBranch() throws {
        let repo = try makeRepo(named: "status")
        try write("hello", to: "a.md", in: repo)

        let status = try client.status(in: repo)
        XCTAssertEqual(status.branch, "main")
        XCTAssertEqual(status.changes.count, 1)
        XCTAssertEqual(status.changes.first?.path, "a.md")
        XCTAssertTrue(status.changes.first?.isUntracked ?? false)
    }

    func testStageThenStatusShowsStaged() throws {
        let repo = try makeRepo(named: "stage")
        try write("hello", to: "a.md", in: repo)

        try client.stage(["a.md"], in: repo)
        let status = try client.status(in: repo)
        XCTAssertTrue(status.changes.first?.isStaged ?? false)
    }

    func testCommitCreatesCommitAndCleansTree() throws {
        let repo = try makeRepo(named: "commit")
        try write("hello", to: "a.md", in: repo)
        try client.stage([], in: repo)

        let commit = try client.commit(message: "Add a.md", in: repo)
        XCTAssertEqual(commit.subject, "Add a.md")
        XCTAssertFalse(commit.sha.isEmpty)
        XCTAssertTrue(try client.status(in: repo).isClean)
    }

    func testLogReturnsNewestFirst() throws {
        let repo = try makeRepo(named: "log")
        try write("1", to: "a.md", in: repo)
        try client.stage([], in: repo)
        _ = try client.commit(message: "First", in: repo)
        try write("2", to: "b.md", in: repo)
        try client.stage([], in: repo)
        _ = try client.commit(message: "Second", in: repo)

        let commits = try client.log(in: repo, maxCount: 10)
        XCTAssertEqual(commits.count, 2)
        XCTAssertEqual(commits[0].subject, "Second")
        XCTAssertEqual(commits[1].subject, "First")
    }

    func testDiffShowsAddedLine() throws {
        let repo = try makeRepo(named: "diff")
        try write("line one\n", to: "a.md", in: repo)
        try client.stage([], in: repo)
        _ = try client.commit(message: "Add a.md", in: repo)

        try write("line one\nline two\n", to: "a.md", in: repo)
        let diffs = try client.diff(in: repo, path: nil, staged: false)
        XCTAssertEqual(diffs.count, 1)
        XCTAssertEqual(diffs.first?.path, "a.md")
        XCTAssertTrue(diffs.first?.patch.contains("+line two") ?? false)
    }

    /// The KujtoSync happy path: two clones of one remote, a push from A, a
    /// clean pull --rebase into B.
    func testPushAndPullRoundTrip() throws {
        let remote = scratch.appendingPathComponent("origin.git")
        try git(["init", "--bare", "-b", "main"], in: {
            try! FileManager.default.createDirectory(at: remote, withIntermediateDirectories: true)
            return remote
        }())

        let a = try makeRepo(named: "a")
        try git(["remote", "add", "origin", remote.path], in: a)
        try write("from A\n", to: "shared.md", in: a)
        try client.stage([], in: a)
        _ = try client.commit(message: "A: first", in: a)
        try git(["push", "-u", "origin", "main"], in: a)

        // B clones, adds its own file, pushes.
        let b = scratch.appendingPathComponent("b")
        try git(["clone", remote.path, b.path], in: scratch)
        try git(["config", "user.name", "B"], in: b)
        try git(["config", "user.email", "b@kujto.dev"], in: b)
        try git(["config", "commit.gpgsign", "false"], in: b)
        try write("from B\n", to: "b-only.md", in: b)
        try client.stage([], in: b)
        _ = try client.commit(message: "B: add b-only", in: b)
        try client.push(in: b)

        // A pulls B's commit. Different files, so a clean rebase.
        let outcome = try client.pullRebase(in: a)
        XCTAssertEqual(outcome, .rebased)
        XCTAssertTrue(FileManager.default.fileExists(atPath: a.appendingPathComponent("b-only.md").path))
    }

    /// A same-line clash must surface as `.conflicted`, never a silent loss.
    func testPullRebaseDetectsConflict() throws {
        let remote = scratch.appendingPathComponent("origin2.git")
        try FileManager.default.createDirectory(at: remote, withIntermediateDirectories: true)
        try git(["init", "--bare", "-b", "main"], in: remote)

        let a = try makeRepo(named: "ca")
        try git(["remote", "add", "origin", remote.path], in: a)
        try write("original\n", to: "rule.md", in: a)
        try client.stage([], in: a)
        _ = try client.commit(message: "seed", in: a)
        try git(["push", "-u", "origin", "main"], in: a)

        // B clones, edits the same line, pushes.
        let b = scratch.appendingPathComponent("cb")
        try git(["clone", remote.path, b.path], in: scratch)
        try git(["config", "user.name", "B"], in: b)
        try git(["config", "user.email", "b@kujto.dev"], in: b)
        try git(["config", "commit.gpgsign", "false"], in: b)
        try write("B wins\n", to: "rule.md", in: b)
        try client.stage([], in: b)
        _ = try client.commit(message: "B edit", in: b)
        try client.push(in: b)

        // A edits the same line, commits, then pulls: conflict.
        try write("A wins\n", to: "rule.md", in: a)
        try client.stage([], in: a)
        _ = try client.commit(message: "A edit", in: a)

        let outcome = try client.pullRebase(in: a)
        guard case let .conflicted(files) = outcome else {
            return XCTFail("expected a conflict, got \(outcome)")
        }
        XCTAssertTrue(files.contains("rule.md"))
    }

    /// A push against a remote that moved must be rejected, not silently lost.
    func testPushRejectedOnNonFastForward() throws {
        let remote = scratch.appendingPathComponent("origin3.git")
        try FileManager.default.createDirectory(at: remote, withIntermediateDirectories: true)
        try git(["init", "--bare", "-b", "main"], in: remote)

        let a = try makeRepo(named: "na")
        try git(["remote", "add", "origin", remote.path], in: a)
        try write("seed\n", to: "x.md", in: a)
        try client.stage([], in: a)
        _ = try client.commit(message: "seed", in: a)
        try git(["push", "-u", "origin", "main"], in: a)

        // B advances the remote.
        let b = scratch.appendingPathComponent("nb")
        try git(["clone", remote.path, b.path], in: scratch)
        try git(["config", "user.name", "B"], in: b)
        try git(["config", "user.email", "b@kujto.dev"], in: b)
        try git(["config", "commit.gpgsign", "false"], in: b)
        try write("b\n", to: "y.md", in: b)
        try client.stage([], in: b)
        _ = try client.commit(message: "B advance", in: b)
        try client.push(in: b)

        // A commits without pulling, then push must be rejected.
        try write("a\n", to: "z.md", in: a)
        try client.stage([], in: a)
        _ = try client.commit(message: "A advance", in: a)
        XCTAssertThrowsError(try client.push(in: a))
    }
}
