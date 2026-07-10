import XCTest
@testable import KujtoCore

final class RuleEventLedgerTests: XCTestCase {

    private func makeLedger(max: Int = 200) -> (RuleEventLedger, URL) {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("kujto-ledger-\(UUID().uuidString)")
        let url = dir.appendingPathComponent("ledger.json")
        return (RuleEventLedger(fileURL: url, maxSnapshotsPerRepo: max), dir)
    }

    private func snapshot(repo: String, at date: Date, level: RiskScore.Level = .watch, score: Int = 20) -> RiskSnapshot {
        RiskSnapshot(repoPath: repo, takenAt: date, level: level, score: score, headline: "h",
                     fileCount: 1, watchCount: 1, escalatingCount: 0, blockedCount: 0,
                     lintErrorCount: 0, lintWarningCount: 0, conflictCount: 0)
    }

    // MARK: - Current and previous

    func testCurrentAndPreviousSnapshot() throws {
        let (ledger, dir) = makeLedger()
        defer { try? FileManager.default.removeItem(at: dir) }
        let repo = "/tmp/repo-a"
        let base = Date(timeIntervalSince1970: 1_000_000)

        try ledger.record(snapshot(repo: repo, at: base, score: 10))
        try ledger.record(snapshot(repo: repo, at: base.addingTimeInterval(60), score: 40))

        XCTAssertEqual(ledger.latestSnapshot(forRepo: repo)?.score, 40)
        XCTAssertEqual(ledger.previousSnapshot(forRepo: repo)?.score, 10)
    }

    func testPreviousIsNilWithOneSnapshot() throws {
        let (ledger, dir) = makeLedger()
        defer { try? FileManager.default.removeItem(at: dir) }
        try ledger.record(snapshot(repo: "/tmp/r", at: Date()))
        XCTAssertNil(ledger.previousSnapshot(forRepo: "/tmp/r"))
    }

    func testEmptyLedgerReadsCleanly() {
        let (ledger, dir) = makeLedger()
        defer { try? FileManager.default.removeItem(at: dir) }
        XCTAssertNil(ledger.latestSnapshot(forRepo: "/tmp/none"))
        XCTAssertTrue(ledger.snapshots(forRepo: "/tmp/none").isEmpty)
    }

    // MARK: - Isolation and persistence

    func testSnapshotsAreScopedPerRepo() throws {
        let (ledger, dir) = makeLedger()
        defer { try? FileManager.default.removeItem(at: dir) }
        try ledger.record(snapshot(repo: "/tmp/a", at: Date(), score: 11))
        try ledger.record(snapshot(repo: "/tmp/b", at: Date(), score: 99))
        XCTAssertEqual(ledger.snapshots(forRepo: "/tmp/a").count, 1)
        XCTAssertEqual(ledger.latestSnapshot(forRepo: "/tmp/a")?.score, 11)
    }

    func testPersistsAcrossInstances() throws {
        let (ledger, dir) = makeLedger()
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = ledger.fileURL
        try ledger.record(snapshot(repo: "/tmp/a", at: Date(), score: 33))

        let reopened = RuleEventLedger(fileURL: url)
        XCTAssertEqual(reopened.latestSnapshot(forRepo: "/tmp/a")?.score, 33)
    }

    func testPruningKeepsNewestPerRepo() throws {
        let (ledger, dir) = makeLedger(max: 3)
        defer { try? FileManager.default.removeItem(at: dir) }
        let base = Date(timeIntervalSince1970: 2_000_000)
        for i in 0..<6 {
            try ledger.record(snapshot(repo: "/tmp/a", at: base.addingTimeInterval(Double(i) * 60), score: i))
        }
        let kept = ledger.snapshots(forRepo: "/tmp/a")
        XCTAssertEqual(kept.count, 3)
        // Newest three are scores 5, 4, 3.
        XCTAssertEqual(kept.map { $0.score }, [5, 4, 3])
    }

    // MARK: - Overrides

    func testActiveOverridesFilterByExpiry() throws {
        let (ledger, dir) = makeLedger()
        defer { try? FileManager.default.removeItem(at: dir) }
        let now = Date(timeIntervalSince1970: 3_000_000)
        try ledger.record(RuleOverride(repoPath: "/tmp/a", reason: "expired",
                                       createdAt: now, expiresAt: now.addingTimeInterval(-10)))
        try ledger.record(RuleOverride(repoPath: "/tmp/a", reason: "live",
                                       createdAt: now, expiresAt: now.addingTimeInterval(600)))
        try ledger.record(RuleOverride(repoPath: "/tmp/a", reason: "permanent"))

        XCTAssertEqual(ledger.overrides(forRepo: "/tmp/a").count, 3)
        let active = ledger.activeOverrides(forRepo: "/tmp/a", at: now)
        XCTAssertEqual(Set(active.map { $0.reason }), ["live", "permanent"])
    }

    // MARK: - Normalization

    func testTrailingSlashNormalizes() throws {
        let (ledger, dir) = makeLedger()
        defer { try? FileManager.default.removeItem(at: dir) }
        try ledger.record(snapshot(repo: "/tmp/a/", at: Date(), score: 7))
        // Querying without the trailing slash must find it.
        XCTAssertEqual(ledger.latestSnapshot(forRepo: "/tmp/a")?.score, 7)
    }
}
