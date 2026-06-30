import XCTest
@testable import KujtoCore

final class MemoryMapTests: XCTestCase {
    private func makeRepo() throws -> URL {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("kujto-map-\(UUID().uuidString)")
        let fm = FileManager.default
        try fm.createDirectory(at: root.appendingPathComponent("memory/domains"), withIntermediateDirectories: true)
        try fm.createDirectory(at: root.appendingPathComponent("skills/proto"), withIntermediateDirectories: true)

        try "# Agents".write(to: root.appendingPathComponent("AGENTS.md"), atomically: true, encoding: .utf8)
        try "# Index".write(to: root.appendingPathComponent("memory/MEMORY.md"), atomically: true, encoding: .utf8)

        let scoped = """
        ---
        applies_to:
          - "**/*Reducer.swift"
        risk: payment
        ---
        # TCA
        body
        """
        try scoped.write(to: root.appendingPathComponent("memory/domains/tca.md"), atomically: true, encoding: .utf8)

        try "# Writing style\nbody".write(
            to: root.appendingPathComponent("memory/style.md"), atomically: true, encoding: .utf8)

        let skill = """
        ---
        applies_to:
          - "**/*View.swift"
        ---
        # Proto skill
        body
        """
        try skill.write(to: root.appendingPathComponent("skills/proto/SKILL.md"), atomically: true, encoding: .utf8)
        return root
    }

    func testScanAggregatesRulesAndPresence() throws {
        let root = try makeRepo()
        defer { try? FileManager.default.removeItem(at: root) }

        let map = try MemoryMapScanner.scan(root: root)

        XCTAssertTrue(map.hasAgentsFile)
        XCTAssertTrue(map.hasMemoryIndex)
        // Sorted by path: memory/domains/tca.md before skills/proto/SKILL.md.
        XCTAssertEqual(map.scopedRules.map { $0.title }, ["TCA", "Proto skill"])
        // MEMORY.md (the index) is itself base memory, read every session.
        XCTAssertEqual(map.baseRules.map { $0.title }, ["Index", "Writing style"])
        XCTAssertEqual(map.riskTags, ["payment"])
        XCTAssertEqual(map.memoryCount, 3)
        XCTAssertEqual(map.skillCount, 1)
    }

    func testScanReportsMissingGovernanceFiles() throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("kujto-empty-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let map = try MemoryMapScanner.scan(root: root)
        XCTAssertFalse(map.hasAgentsFile)
        XCTAssertFalse(map.hasMemoryIndex)
        XCTAssertTrue(map.scopedRules.isEmpty)
        XCTAssertTrue(map.baseRules.isEmpty)
    }
}
