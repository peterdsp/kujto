import XCTest
@testable import KujtoGit

/// Pure parser tests. No repo, no git binary, fully deterministic. These pin
/// the porcelain and log formats we depend on so a git output change is caught
/// here rather than in the flaky integration layer.
final class ParsingTests: XCTestCase {

    // MARK: Branch header

    func testBranchHeaderWithUpstreamAndTracking() {
        let (branch, upstream, ahead, behind) =
            ShellGitClient.parseBranchHeader("main...origin/main [ahead 2, behind 3]")
        XCTAssertEqual(branch, "main")
        XCTAssertEqual(upstream, "origin/main")
        XCTAssertEqual(ahead, 2)
        XCTAssertEqual(behind, 3)
    }

    func testBranchHeaderAheadOnly() {
        let (branch, upstream, ahead, behind) =
            ShellGitClient.parseBranchHeader("main...origin/main [ahead 1]")
        XCTAssertEqual(branch, "main")
        XCTAssertEqual(upstream, "origin/main")
        XCTAssertEqual(ahead, 1)
        XCTAssertEqual(behind, 0)
    }

    func testBranchHeaderNoUpstream() {
        let (branch, upstream, ahead, behind) = ShellGitClient.parseBranchHeader("feature/x")
        XCTAssertEqual(branch, "feature/x")
        XCTAssertNil(upstream)
        XCTAssertEqual(ahead, 0)
        XCTAssertEqual(behind, 0)
    }

    func testBranchHeaderEmptyRepo() {
        let (branch, upstream, _, _) = ShellGitClient.parseBranchHeader("No commits yet on main")
        XCTAssertEqual(branch, "main")
        XCTAssertNil(upstream)
    }

    // MARK: Change entries

    func testParseUntracked() {
        let change = ShellGitClient.parseChange("?? notes.md")
        XCTAssertEqual(change?.path, "notes.md")
        XCTAssertTrue(change?.isUntracked ?? false)
        XCTAssertFalse(change?.isStaged ?? true)
    }

    func testParseStagedModification() {
        let change = ShellGitClient.parseChange("M  Sources/App.swift")
        XCTAssertEqual(change?.path, "Sources/App.swift")
        XCTAssertEqual(change?.index, .modified)
        XCTAssertEqual(change?.worktree, .unmodified)
        XCTAssertTrue(change?.isStaged ?? false)
    }

    func testParseRename() {
        let change = ShellGitClient.parseChange("R  old/name.md -> new/name.md")
        XCTAssertEqual(change?.path, "new/name.md")
        XCTAssertEqual(change?.originalPath, "old/name.md")
        XCTAssertEqual(change?.index, .renamed)
    }

    func testParseUnmergedIsConflicted() {
        let change = ShellGitClient.parseChange("UU rules/tca.md")
        XCTAssertTrue(change?.isConflicted ?? false)
    }

    // MARK: Full status

    func testParseStatusBranchPlusChanges() {
        let output = """
        ## main...origin/main [ahead 1]
        M  a.md
         M b.md
        ?? c.md
        """
        let status = ShellGitClient.parseStatus(output)
        XCTAssertEqual(status.branch, "main")
        XCTAssertEqual(status.ahead, 1)
        XCTAssertEqual(status.changes.count, 3)
        XCTAssertFalse(status.isClean)
    }

    func testParseStatusCleanTree() {
        let status = ShellGitClient.parseStatus("## main...origin/main\n")
        XCTAssertTrue(status.isClean)
        XCTAssertEqual(status.branch, "main")
    }

    // MARK: Diff splitting

    func testSplitPatchesTwoFiles() {
        let output = """
        diff --git a/one.md b/one.md
        index 111..222 100644
        --- a/one.md
        +++ b/one.md
        @@ -1 +1 @@
        -old
        +new
        diff --git a/two.md b/two.md
        index 333..444 100644
        --- a/two.md
        +++ b/two.md
        @@ -0,0 +1 @@
        +added
        """
        let diffs = ShellGitClient.splitPatches(output)
        XCTAssertEqual(diffs.count, 2)
        XCTAssertEqual(diffs[0].path, "one.md")
        XCTAssertEqual(diffs[1].path, "two.md")
        XCTAssertTrue(diffs[0].patch.contains("+new"))
    }

    func testSplitPatchesEmpty() {
        XCTAssertTrue(ShellGitClient.splitPatches("").isEmpty)
    }

    // MARK: Log

    func testParseLogTwoCommits() {
        let u = "\u{1f}"
        let r = "\u{1e}"
        let output = [
            "abc123\(u)abc\(u)Ada\(u)ada@x.dev\(u)2026-07-20T10:00:00Z\(u)Second\(u)body two",
            "def456\(u)def\(u)Ada\(u)ada@x.dev\(u)2026-07-19T10:00:00Z\(u)First\(u)"
        ].joined(separator: r) + r
        let commits = ShellGitClient.parseLog(output)
        XCTAssertEqual(commits.count, 2)
        XCTAssertEqual(commits[0].sha, "abc123")
        XCTAssertEqual(commits[0].subject, "Second")
        XCTAssertEqual(commits[0].body, "body two")
        XCTAssertEqual(commits[1].subject, "First")
        XCTAssertEqual(commits[1].body, "")
    }
}
