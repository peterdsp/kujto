import XCTest
@testable import KujtoSync
import KujtoGit

/// The auto-commit message must be deterministic (so two machines agree) and
/// readable (so the synced history is a legible memory log, not noise).
final class CommitMessageBuilderTests: XCTestCase {

    private func change(_ path: String) -> GitChange {
        GitChange(path: path, index: .modified, worktree: .unmodified)
    }

    func testSingleFile() {
        let msg = CommitMessageBuilder.message(for: [change("rules/tca.md")])
        XCTAssertEqual(msg, "memory: update rules/tca.md (1 file)")
    }

    func testTwoFilesSortedAndPluralized() {
        let msg = CommitMessageBuilder.message(for: [change("skills/proto.md"), change("core/style.md")])
        XCTAssertEqual(msg, "memory: update core/style.md, skills/proto.md (2 files)")
    }

    func testTruncatesBeyondMaxNamed() {
        let changes = ["a.md", "b.md", "c.md", "d.md", "e.md"].map(change)
        let msg = CommitMessageBuilder.message(for: changes, maxNamed: 3)
        XCTAssertEqual(msg, "memory: update a.md, b.md, c.md and 2 more (5 files)")
    }

    func testDeduplicatesPaths() {
        // A path staged and modified can appear twice; the message names it once.
        let msg = CommitMessageBuilder.message(for: [change("a.md"), change("a.md")])
        XCTAssertEqual(msg, "memory: update a.md (1 file)")
    }

    func testEmptyIsSafe() {
        XCTAssertEqual(CommitMessageBuilder.message(for: []), "memory: sync")
    }
}
