import XCTest
@testable import KujtoCore

final class AgentExportTests: XCTestCase {
    private struct Layout { let root: URL; let target: URL }

    private func makeLayout() throws -> Layout {
        let base = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("kujto-agents-\(UUID().uuidString)")
        let root = base.appendingPathComponent("kujto")
        let target = base.appendingPathComponent("client")
        let fm = FileManager.default
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        try fm.createDirectory(at: target, withIntermediateDirectories: true)
        try "# Agents".write(to: root.appendingPathComponent("AGENTS.md"), atomically: true, encoding: .utf8)
        return Layout(root: root, target: target)
    }

    func testReportsNotPresentForEmptyTarget() throws {
        let layout = try makeLayout()
        defer { try? FileManager.default.removeItem(at: layout.root.deletingLastPathComponent()) }

        let statuses = AgentExport.status(target: layout.target, root: layout.root)
        XCTAssertEqual(statuses.count, AgentKind.allCases.count)
        XCTAssertTrue(statuses.allSatisfy { $0.state == .notPresent })
    }

    func testReportsLinkedWhenSymlinkMatchesRoot() throws {
        let layout = try makeLayout()
        defer { try? FileManager.default.removeItem(at: layout.root.deletingLastPathComponent()) }

        let claudeFile = layout.target.appendingPathComponent("CLAUDE.md")
        try FileManager.default.createSymbolicLink(
            at: claudeFile,
            withDestinationURL: layout.root.appendingPathComponent("AGENTS.md")
        )

        let statuses = AgentExport.status(target: layout.target, root: layout.root)
        let claude = statuses.first { $0.agent == .claude }
        XCTAssertEqual(claude?.state, .linked)
        XCTAssertNotNil(claude?.linkDestination)
    }

    func testReportsForeignWhenFileIsRegular() throws {
        let layout = try makeLayout()
        defer { try? FileManager.default.removeItem(at: layout.root.deletingLastPathComponent()) }

        try "# Their own Claude file"
            .write(to: layout.target.appendingPathComponent("CLAUDE.md"), atomically: true, encoding: .utf8)

        let statuses = AgentExport.status(target: layout.target, root: layout.root)
        let claude = statuses.first { $0.agent == .claude }
        XCTAssertEqual(claude?.state, .foreign)
        XCTAssertNil(claude?.linkDestination)
    }

    func testReportsForeignWhenSymlinkPointsElsewhere() throws {
        let layout = try makeLayout()
        defer { try? FileManager.default.removeItem(at: layout.root.deletingLastPathComponent()) }

        let other = layout.root.deletingLastPathComponent().appendingPathComponent("OTHER.md")
        try "# Other".write(to: other, atomically: true, encoding: .utf8)
        try FileManager.default.createSymbolicLink(
            at: layout.target.appendingPathComponent("CODEX.md"),
            withDestinationURL: other
        )

        let statuses = AgentExport.status(target: layout.target, root: layout.root)
        let codex = statuses.first { $0.agent == .codex }
        XCTAssertEqual(codex?.state, .foreign)
        XCTAssertEqual(codex?.linkDestination, other.path)
    }
}
