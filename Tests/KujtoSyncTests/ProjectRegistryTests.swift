import XCTest
@testable import KujtoSync

/// The registry is synced through git, so its identity semantics (upsert by
/// remote) and its stable normalization matter as much as its contents.
final class ProjectRegistryTests: XCTestCase {

    private func project(_ name: String, remote: String, agents: [String] = []) -> RegisteredProject {
        RegisteredProject(name: name, remote: remote, wiredAgents: agents, localPathHint: "~/git/\(name)")
    }

    func testUpsertReplacesByRemote() {
        var registry = ProjectRegistry()
        registry.upsert(project("Syrmos", remote: "git@x:peterdsp/syrmos.git", agents: ["claude"]))
        registry.upsert(project("Syrmos Renamed", remote: "git@x:peterdsp/syrmos.git", agents: ["claude", "codex"]))

        XCTAssertEqual(registry.projects.count, 1)
        XCTAssertEqual(registry.projects.first?.name, "Syrmos Renamed")
        XCTAssertEqual(registry.projects.first?.wiredAgents, ["claude", "codex"])
    }

    func testUpsertAppendsDistinctRemotes() {
        var registry = ProjectRegistry()
        registry.upsert(project("A", remote: "git@x:a.git"))
        registry.upsert(project("B", remote: "git@x:b.git"))
        XCTAssertEqual(registry.projects.count, 2)
    }

    func testRemoveByRemote() {
        var registry = ProjectRegistry(projects: [project("A", remote: "git@x:a.git")])
        registry.remove(remote: "git@x:a.git")
        XCTAssertTrue(registry.projects.isEmpty)
    }

    func testNormalizeSortsProjectsAndArrays() {
        let registry = ProjectRegistry(projects: [
            project("Zeta", remote: "git@x:z.git", agents: ["codex", "claude", "codex"]),
            project("Alpha", remote: "git@x:a.git")
        ])
        let normalized = registry.normalized()
        XCTAssertEqual(normalized.projects.map { $0.name }, ["Alpha", "Zeta"])
        // Agents deduplicated and sorted.
        XCTAssertEqual(normalized.projects[1].wiredAgents, ["claude", "codex"])
    }

    func testHintForLocalPathUnderHome() {
        let home = URL(fileURLWithPath: "/Users/ada")
        let path = URL(fileURLWithPath: "/Users/ada/git/personal/Syrmos")
        XCTAssertEqual(RegisteredProject.hint(forLocalPath: path, home: home), "~/git/personal/Syrmos")
    }

    func testHintForHomeItself() {
        let home = URL(fileURLWithPath: "/Users/ada")
        XCTAssertEqual(RegisteredProject.hint(forLocalPath: home, home: home), "~")
    }

    func testHintForPathOutsideHomeIsVerbatim() {
        let home = URL(fileURLWithPath: "/Users/ada")
        let path = URL(fileURLWithPath: "/opt/work/thing")
        XCTAssertEqual(RegisteredProject.hint(forLocalPath: path, home: home), "/opt/work/thing")
    }
}
