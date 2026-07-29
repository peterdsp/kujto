import XCTest
@testable import KujtoAgents

final class UsageAttributorTests: XCTestCase {
    func testAttributesToActiveAccount() {
        var log = SwitchLog()
        log.record("work", at: Date(timeIntervalSince1970: 100))

        let usage = [
            SessionUsage(sessionID: "s1", timestamp: Date(timeIntervalSince1970: 200),
                         model: "claude-sonnet-4", inputTokens: 1000, outputTokens: 500),
        ]

        let result = UsageAttributor().attribute(usage, with: log)
        XCTAssertEqual(result.snapshots.count, 1)
        XCTAssertEqual(result.snapshots[0].profileID, "work")
        XCTAssertEqual(result.snapshots[0].inputTokens, 1000)
        XCTAssertEqual(result.unattributedTokens, 0)
    }

    func testUsageBeforeFirstSwitchIsUnattributed() {
        var log = SwitchLog()
        log.record("work", at: Date(timeIntervalSince1970: 500))

        let usage = [
            SessionUsage(sessionID: "s0", timestamp: Date(timeIntervalSince1970: 100),
                         model: "claude-sonnet-4", inputTokens: 300, outputTokens: 200),
            SessionUsage(sessionID: "s1", timestamp: Date(timeIntervalSince1970: 600),
                         model: "claude-sonnet-4", inputTokens: 100, outputTokens: 50),
        ]

        let result = UsageAttributor().attribute(usage, with: log)
        XCTAssertEqual(result.snapshots.count, 1)
        XCTAssertEqual(result.snapshots[0].profileID, "work")
        XCTAssertEqual(result.unattributedTokens, 500)
        XCTAssertEqual(result.unattributedRecords, 1)
    }

    func testMultipleAccountAttribution() {
        var log = SwitchLog()
        log.record("work", at: Date(timeIntervalSince1970: 100))
        log.record("personal", at: Date(timeIntervalSince1970: 300))

        let usage = [
            SessionUsage(sessionID: "s1", timestamp: Date(timeIntervalSince1970: 200),
                         model: "claude-opus-4", inputTokens: 500, outputTokens: 100),
            SessionUsage(sessionID: "s2", timestamp: Date(timeIntervalSince1970: 400),
                         model: "claude-haiku-4", inputTokens: 200, outputTokens: 50),
        ]

        let result = UsageAttributor().attribute(usage, with: log)
        XCTAssertEqual(result.snapshots.count, 2)
        let work = result.snapshots.first { $0.profileID == "work" }
        let personal = result.snapshots.first { $0.profileID == "personal" }
        XCTAssertEqual(work?.totalTokens, 600)
        XCTAssertEqual(personal?.totalTokens, 250)
    }

    func testModelBreakdownIsPopulated() {
        var log = SwitchLog()
        log.record("a", at: Date(timeIntervalSince1970: 0))

        let usage = [
            SessionUsage(sessionID: "s1", timestamp: Date(timeIntervalSince1970: 100),
                         model: "claude-opus-4", inputTokens: 1000, outputTokens: 500),
            SessionUsage(sessionID: "s1", timestamp: Date(timeIntervalSince1970: 200),
                         model: "claude-sonnet-4-20260115", inputTokens: 2000, outputTokens: 300),
            SessionUsage(sessionID: "s1", timestamp: Date(timeIntervalSince1970: 300),
                         model: "claude-opus-4", inputTokens: 500, outputTokens: 100),
        ]

        let result = UsageAttributor().attribute(usage, with: log)
        let snapshot = result.snapshots[0]
        XCTAssertEqual(snapshot.modelBreakdown.count, 2)
        XCTAssertEqual(snapshot.modelBreakdown[0].model, "claude-sonnet-4")
        XCTAssertEqual(snapshot.modelBreakdown[1].model, "claude-opus-4")
        XCTAssertEqual(snapshot.turns, 3)
    }

    func testEmptyLogEmptyUsage() {
        let result = UsageAttributor().attribute([], with: SwitchLog())
        XCTAssertTrue(result.snapshots.isEmpty)
        XCTAssertEqual(result.unattributedTokens, 0)
    }
}
