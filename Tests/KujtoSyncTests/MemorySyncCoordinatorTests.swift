import XCTest
@testable import KujtoSync
import KujtoGit
import KujtoCore

/// The coordinator actor is what the app service wraps: it serializes ticks and
/// tracks status. These tests drive it against real temp repos so the glue the
/// app relies on (syncNow returns an outcome and updates status) is covered.
final class MemorySyncCoordinatorTests: XCTestCase {
    private var scratch: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        scratch = FileManager.default.temporaryDirectory
            .appendingPathComponent("kujto-coord-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let scratch = scratch { try? FileManager.default.removeItem(at: scratch) }
        try super.tearDownWithError()
    }

    @discardableResult
    private func git(_ args: [String], in repo: URL) throws -> String {
        let r = try ProcessRunner().run("git", arguments: ["-C", repo.path] + args)
        XCTAssertEqual(r.exitCode, 0, r.stderr)
        return r.stdout
    }

    private func makeRepo(_ name: String) throws -> URL {
        let repo = scratch.appendingPathComponent(name)
        try FileManager.default.createDirectory(at: repo, withIntermediateDirectories: true)
        try git(["init", "-b", "main"], in: repo)
        try git(["config", "user.name", "T"], in: repo)
        try git(["config", "user.email", "t@x"], in: repo)
        try git(["config", "commit.gpgsign", "false"], in: repo)
        return repo
    }

    func testInitialStatusIsIdle() async {
        let repo = URL(fileURLWithPath: "/tmp/none")
        let coordinator = MemorySyncCoordinator(repo: repo)
        let status = await coordinator.status
        XCTAssertEqual(status, .idle)
    }

    func testSyncNowCleanRepoIsSynced() async throws {
        let repo = try makeRepo("clean")
        let coordinator = MemorySyncCoordinator(repo: repo)

        let outcome = await coordinator.syncNow()
        XCTAssertEqual(outcome, .clean)
        let status = await coordinator.status
        XCTAssertEqual(status, .synced)
    }

    func testSyncNowCommitsLocalChange() async throws {
        let repo = try makeRepo("dirty")
        let file = repo.appendingPathComponent("rules/a.md")
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        try "# rule\n".write(to: file, atomically: true, encoding: .utf8)

        let coordinator = MemorySyncCoordinator(repo: repo)
        _ = await coordinator.syncNow()

        // The change was committed: the tree is clean afterward.
        XCTAssertTrue(try ShellGitClient().status(in: repo).isClean)
        let last = await coordinator.lastOutcome
        XCTAssertEqual(last, .localOnly)
    }
}
