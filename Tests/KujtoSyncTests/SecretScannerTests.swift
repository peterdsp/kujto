import XCTest
@testable import KujtoSync
import KujtoGit

/// The secret guard must catch high-signal credential shapes on added lines
/// only, and must not fire on ordinary code. It is the one thing standing
/// between a careless paste and a token leaving the machine.
final class SecretScannerTests: XCTestCase {
    private let scanner = SecretScanner()

    private func added(_ line: String, file: String = "core/notes.md") -> [SecretHit] {
        scanner.scanPatch("@@ -0,0 +1 @@\n+\(line)", file: file)
    }

    func testCatchesGitHubToken() {
        let hits = added("token: ghp_0123456789abcdefghijklmnopqrstuvwxyzABCD")
        XCTAssertEqual(hits.first?.kind, "github-token")
        XCTAssertEqual(hits.first?.file, "core/notes.md")
    }

    func testCatchesAnthropicKey() {
        let hits = added("KEY=sk-ant-api03-abcdefghijklmnopqrstuvwxyz123")
        XCTAssertEqual(hits.first?.kind, "openai-anthropic-key")
    }

    func testCatchesAwsAccessKey() {
        let hits = added("aws = AKIAIOSFODNN7EXAMPLE")
        XCTAssertEqual(hits.first?.kind, "aws-access-key")
    }

    func testCatchesSlackToken() {
        let hits = added("slack: xoxb-1234567890-abcdefghij")
        XCTAssertEqual(hits.first?.kind, "slack-token")
    }

    func testCatchesPrivateKeyBlock() {
        let hits = added("-----BEGIN RSA PRIVATE KEY-----")
        XCTAssertEqual(hits.first?.kind, "private-key-block")
    }

    func testIgnoresOrdinaryProse() {
        XCTAssertTrue(added("Effects must be cancellable on onDisappear.").isEmpty)
        XCTAssertTrue(added("Call getToken() before the request.").isEmpty)
    }

    func testIgnoresRemovedAndContextLines() {
        // A secret on a removed line or a context line is not being added, so
        // it must not block a commit.
        let patch = """
        @@ -1,2 +1,1 @@
        -ghp_0123456789abcdefghijklmnopqrstuvwxyzABCD
         context ghp_0123456789abcdefghijklmnopqrstuvwxyzABCD
        """
        XCTAssertTrue(scanner.scanPatch(patch, file: "x.md").isEmpty)
    }

    func testMaskNeverEchoesRawToken() {
        let hits = added("ghp_0123456789abcdefghijklmnopqrstuvwxyzABCD")
        let masked = hits.first?.masked ?? ""
        XCTAssertTrue(masked.contains("***"))
        XCTAssertFalse(masked.contains("0123456789abcdefghij"))
    }

    func testLineNumberTracksHunkHeader() {
        let patch = """
        @@ -10,0 +10,2 @@
        +harmless line
        +ghp_0123456789abcdefghijklmnopqrstuvwxyzABCD
        """
        let hits = scanner.scanPatch(patch, file: "x.md")
        XCTAssertEqual(hits.first?.line, 11)
    }

    func testScanDiffAcrossFiles() {
        let diffs = [
            GitFileDiff(path: "a.md", patch: "@@ -0,0 +1 @@\n+clean line"),
            GitFileDiff(path: "b.md", patch: "@@ -0,0 +1 @@\n+ghp_0123456789abcdefghijklmnopqrstuvwxyzABCD")
        ]
        let hits = scanner.scanDiff(diffs)
        XCTAssertEqual(hits.count, 1)
        XCTAssertEqual(hits.first?.file, "b.md")
    }
}
