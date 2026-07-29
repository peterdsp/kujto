import XCTest
@testable import KujtoAgents

final class SwitchLogTests: XCTestCase {
    func testAccountAtTimeReturnsActiveProfile() {
        var log = SwitchLog()
        let t0 = Date(timeIntervalSince1970: 1000)
        let t1 = Date(timeIntervalSince1970: 2000)
        log.record("a", at: t0)
        log.record("b", at: t1)

        XCTAssertNil(log.account(at: Date(timeIntervalSince1970: 500)))
        XCTAssertEqual(log.account(at: t0), "a")
        XCTAssertEqual(log.account(at: Date(timeIntervalSince1970: 1500)), "a")
        XCTAssertEqual(log.account(at: t1), "b")
        XCTAssertEqual(log.account(at: Date(timeIntervalSince1970: 9999)), "b")
    }

    func testBeforeFirstSwitchIsNil() {
        var log = SwitchLog()
        log.record("a", at: Date(timeIntervalSince1970: 1000))
        XCTAssertNil(log.account(at: Date(timeIntervalSince1970: 999)))
    }

    func testPruneKeepsBoundaryEvent() {
        var log = SwitchLog()
        log.record("a", at: Date(timeIntervalSince1970: 100))
        log.record("b", at: Date(timeIntervalSince1970: 200))
        log.record("c", at: Date(timeIntervalSince1970: 300))
        log.prune(before: Date(timeIntervalSince1970: 250))
        XCTAssertEqual(log.events.count, 2)
        XCTAssertEqual(log.events.first?.profileID, "b")
    }

    func testRecordKeepsChronologicalOrder() {
        var log = SwitchLog()
        log.record("b", at: Date(timeIntervalSince1970: 200))
        log.record("a", at: Date(timeIntervalSince1970: 100))
        XCTAssertEqual(log.events.map(\.profileID), ["a", "b"])
    }

    func testStoreRoundTrip() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("kujto-switchlog-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }

        let store = SwitchLogStore(root: root)
        try store.record("work", at: Date(timeIntervalSince1970: 12345))
        try store.record("personal", at: Date(timeIntervalSince1970: 67890))

        let loaded = try store.load()
        XCTAssertEqual(loaded.events.count, 2)
        XCTAssertEqual(loaded.events[0].profileID, "work")
        XCTAssertEqual(loaded.events[1].profileID, "personal")
        XCTAssertEqual(loaded.events[0].at.timeIntervalSince1970, 12345, accuracy: 1)
    }

    func testMissingFileLoadsEmpty() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("kujto-switchlog-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }

        let loaded = try SwitchLogStore(root: root).load()
        XCTAssertTrue(loaded.events.isEmpty)
    }
}
