import XCTest
@testable import KujtoGit
import KujtoCore

/// Clone and remote-URL reads: the two primitives rehydrate needs to place a
/// project on a new machine and to recognize one that is already there.
final class CloneTests: XCTestCase {
    private let client = ShellGitClient()
    private var scratch: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        scratch = FileManager.default.temporaryDirectory
            .appendingPathComponent("kujtogit-clone-\(UUID().uuidString)")
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

    private func makeSourceRepo() throws -> URL {
        let repo = scratch.appendingPathComponent("source")
        try FileManager.default.createDirectory(at: repo, withIntermediateDirectories: true)
        try git(["init", "-b", "main"], in: repo)
        try git(["config", "user.name", "Test"], in: repo)
        try git(["config", "user.email", "test@kujto.dev"], in: repo)
        try git(["config", "commit.gpgsign", "false"], in: repo)
        try "hello\n".write(to: repo.appendingPathComponent("a.md"), atomically: true, encoding: .utf8)
        try git(["add", "-A"], in: repo)
        try git(["commit", "-m", "seed"], in: repo)
        return repo
    }

    func testCloneCreatesWorkingCopy() throws {
        let source = try makeSourceRepo()
        let dest = scratch.appendingPathComponent("cloned")

        try client.clone(source.path, to: dest)

        XCTAssertTrue(client.isRepository(dest))
        XCTAssertTrue(FileManager.default.fileExists(atPath: dest.appendingPathComponent("a.md").path))
    }

    func testRemoteURLAfterClone() throws {
        let source = try makeSourceRepo()
        let dest = scratch.appendingPathComponent("cloned2")
        try client.clone(source.path, to: dest)

        XCTAssertEqual(client.remoteURL(in: dest), source.path)
    }

    func testRemoteURLNilWithoutOrigin() throws {
        let source = try makeSourceRepo()
        XCTAssertNil(client.remoteURL(in: source))
    }

    func testCloneFailsForMissingRemote() {
        let dest = scratch.appendingPathComponent("nope")
        XCTAssertThrowsError(try client.clone(scratch.appendingPathComponent("does-not-exist").path, to: dest))
    }
}
