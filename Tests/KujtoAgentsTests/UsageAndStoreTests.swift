import XCTest
@testable import KujtoAgents

/// Usage aggregation (so the user knows where they are) and the roster store's
/// refusal to write anything that looks like a credential.
final class UsageAndStoreTests: XCTestCase {
    private let tracker = UsageTracker()

    // MARK: Usage

    func testAggregatesPerAccount() {
        let records = [
            UsageTracker.Record(profileID: "a", inputTokens: 100, outputTokens: 50, costUSD: 0.5, sessionID: "s1"),
            UsageTracker.Record(profileID: "a", inputTokens: 200, outputTokens: 25, costUSD: 0.25, sessionID: "s1"),
            UsageTracker.Record(profileID: "b", inputTokens: 10, outputTokens: 5, sessionID: "s9"),
        ]
        let snapshots = tracker.snapshots(from: records)
        XCTAssertEqual(snapshots.count, 2)

        let a = snapshots[0]
        XCTAssertEqual(a.inputTokens, 300)
        XCTAssertEqual(a.outputTokens, 75)
        XCTAssertEqual(a.totalTokens, 375)
        XCTAssertEqual(a.costUSD, 0.75)
        XCTAssertEqual(a.sessions, 1, "same session id counted once")
    }

    func testMissingCostStaysNilRatherThanZero() {
        // A confident $0.00 would be a lie; nil renders as "no cost reported".
        let snapshot = tracker.snapshot(for: "b", from: [
            UsageTracker.Record(profileID: "b", inputTokens: 10, outputTokens: 5),
        ])
        XCTAssertNil(snapshot.costUSD)
        XCTAssertFalse(snapshot.summary.contains("$"))
    }

    func testUnknownAccountGivesEmptySnapshot() {
        let snapshot = tracker.snapshot(for: "ghost", from: [])
        XCTAssertEqual(snapshot.totalTokens, 0)
        XCTAssertEqual(snapshot.profileID, "ghost")
    }

    func testCompactFormatting() {
        XCTAssertEqual(UsageSnapshot.compact(999), "999")
        XCTAssertEqual(UsageSnapshot.compact(1_500), "1.5k")
        XCTAssertEqual(UsageSnapshot.compact(2_400_000), "2.4M")
    }

    func testSummaryLine() {
        let snapshot = UsageSnapshot(profileID: "a", inputTokens: 1_000, outputTokens: 500,
                                     costUSD: 1.5, sessions: 3)
        XCTAssertEqual(snapshot.summary, "1.5k tokens · $1.50 · 3 sessions")
    }

    // MARK: Store

    private func makeRepo() throws -> URL {
        let repo = FileManager.default.temporaryDirectory
            .appendingPathComponent("kujto-accounts-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: repo, withIntermediateDirectories: true)
        return repo
    }

    func testRoundTrip() throws {
        let repo = try makeRepo()
        defer { try? FileManager.default.removeItem(at: repo) }
        let store = AccountRosterStore(repo: repo)

        var roster = AccountRoster()
        roster.upsert(AccountProfile(id: "w", label: "Work", vendor: .claude, authMode: .vertex,
                                     settings: ["vertexProject": "acme", "vertexRegion": "us-east5"]))
        roster.activeID = "w"
        try store.save(roster)

        let loaded = try store.load()
        XCTAssertEqual(loaded.activeID, "w")
        XCTAssertEqual(loaded.profile("w")?.settings["vertexProject"], "acme")
    }

    func testMissingFileLoadsEmpty() throws {
        let repo = try makeRepo()
        defer { try? FileManager.default.removeItem(at: repo) }
        XCTAssertTrue(try AccountRosterStore(repo: repo).load().profiles.isEmpty)
    }

    func testRefusesSecretLookingKey() throws {
        let repo = try makeRepo()
        defer { try? FileManager.default.removeItem(at: repo) }
        let roster = AccountRoster(profiles: [
            AccountProfile(id: "x", label: "X", vendor: .claude, authMode: .apiKey,
                           settings: ["apiKey": "whatever"]),
        ])
        XCTAssertThrowsError(try AccountRosterStore(repo: repo).save(roster)) { error in
            XCTAssertEqual(error as? AccountStoreError, .refusedSecretInSettings("x.apiKey"))
        }
    }

    func testRefusesSecretLookingValue() throws {
        let repo = try makeRepo()
        defer { try? FileManager.default.removeItem(at: repo) }
        let roster = AccountRoster(profiles: [
            AccountProfile(id: "x", label: "X", vendor: .claude, authMode: .apiKey,
                           settings: ["note": "sk-ant-abcdefghijklmnopqrstuvwxyz"]),
        ])
        XCTAssertThrowsError(try AccountRosterStore(repo: repo).save(roster))
    }

    func testAllowsOrdinaryRoutingValues() throws {
        let repo = try makeRepo()
        defer { try? FileManager.default.removeItem(at: repo) }
        // Project ids and regions must not trip the guard.
        let roster = AccountRoster(profiles: [
            AccountProfile(id: "w", label: "W", vendor: .claude, authMode: .vertex,
                           settings: ["vertexProject": "acme-prod-1234", "vertexRegion": "us-east5"]),
        ])
        XCTAssertNoThrow(try AccountRosterStore(repo: repo).save(roster))
    }

    func testUpsertAndRemoveClearsActive() {
        var roster = AccountRoster()
        roster.upsert(AccountProfile(id: "a", label: "A", vendor: .claude, authMode: .subscription))
        roster.activeID = "a"
        roster.remove("a")
        XCTAssertTrue(roster.profiles.isEmpty)
        XCTAssertNil(roster.activeID, "active cleared with the profile")
    }
}
