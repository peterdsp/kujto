import XCTest
@testable import KujtoStudioUI
import KujtoGit
import KujtoSync

/// The panel view-model logic: splitting rows, the commit gate, and the commit
/// flow, all driven by a fake client with no real repo.
@MainActor
final class GitPanelModelTests: XCTestCase {
    private let repo = URL(fileURLWithPath: "/tmp/fake")

    private func change(_ path: String, index: GitChange.State, worktree: GitChange.State) -> GitChange {
        GitChange(path: path, index: index, worktree: worktree)
    }

    private func status(_ changes: [GitChange], branch: String? = "main") -> GitStatus {
        GitStatus(branch: branch, upstream: "origin/main", ahead: 0, behind: 0, changes: changes)
    }

    func testRefreshSplitsStagedAndUnstaged() async throws {
        let changes = [
            change("staged.md", index: .modified, worktree: .unmodified),
            change("dirty.md", index: .unmodified, worktree: .modified),
            change("new.md", index: .untracked, worktree: .untracked)
        ]
        let client = FakeGitClient(status: status(changes))
        let model = GitPanelModel(repo: repo, client: client)

        try await model.refresh()

        XCTAssertEqual(model.branch, "main")
        XCTAssertEqual(model.staged.map { $0.path }, ["staged.md"])
        XCTAssertEqual(Set(model.unstaged.map { $0.path }), ["dirty.md", "new.md"])
    }

    func testCanCommitRequiresStagedAndMessage() async throws {
        let client = FakeGitClient(status: status([
            change("staged.md", index: .modified, worktree: .unmodified)
        ]))
        let model = GitPanelModel(repo: repo, client: client)
        try await model.refresh()

        XCTAssertFalse(model.canCommit, "no message yet")
        model.commitMessage = "   "
        XCTAssertFalse(model.canCommit, "whitespace-only message")
        model.commitMessage = "memory: update"
        XCTAssertTrue(model.canCommit)
    }

    func testCanCommitFalseWhenNothingStaged() async throws {
        let client = FakeGitClient(status: status([
            change("dirty.md", index: .unmodified, worktree: .modified)
        ]))
        let model = GitPanelModel(repo: repo, client: client)
        try await model.refresh()
        model.commitMessage = "has a message"
        XCTAssertFalse(model.canCommit)
    }

    func testCommitSendsMessageAndClears() async throws {
        let client = FakeGitClient(status: status([
            change("staged.md", index: .modified, worktree: .unmodified)
        ]))
        let model = GitPanelModel(repo: repo, client: client)
        try await model.refresh()
        model.commitMessage = "memory: update staged.md"

        try await model.commit()

        XCTAssertEqual(client.committedMessages, ["memory: update staged.md"])
        XCTAssertEqual(model.commitMessage, "", "message clears after commit")
        XCTAssertTrue(model.staged.isEmpty, "tree is clean after commit")
    }

    func testCommitNoOpWhenNotAllowed() async throws {
        let client = FakeGitClient(status: status([]))
        let model = GitPanelModel(repo: repo, client: client)
        try await model.refresh()
        model.commitMessage = "message but nothing staged"

        try await model.commit()
        XCTAssertTrue(client.committedMessages.isEmpty)
    }

    func testStageForwardsPathAndRefreshes() async throws {
        let client = FakeGitClient(status: status([
            change("new.md", index: .untracked, worktree: .untracked)
        ]))
        let model = GitPanelModel(repo: repo, client: client)
        try await model.refresh()

        try await model.stage(model.unstaged[0])
        XCTAssertEqual(client.stagedCalls, [["new.md"]])
    }

    func testSetSyncStatusUpdatesGlyphState() async throws {
        let model = GitPanelModel(repo: repo, client: FakeGitClient(status: status([])))
        model.setSyncStatus(.needsAttention)
        XCTAssertEqual(model.syncStatus, .needsAttention)
    }
}
