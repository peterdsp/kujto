import XCTest
@testable import KujtoSync

/// The store guards the synced repo's schema: it initializes cleanly, refuses a
/// repo from a newer Kujto, migrates an older one forward, and serializes
/// stably so the registry's git history stays merge-clean.
final class RegistryStoreTests: XCTestCase {
    private var repo: URL!
    private var store: RegistryStore!

    override func setUpWithError() throws {
        try super.setUpWithError()
        repo = FileManager.default.temporaryDirectory
            .appendingPathComponent("kujto-registry-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: repo, withIntermediateDirectories: true)
        store = RegistryStore(repo: repo)
    }

    override func tearDownWithError() throws {
        if let repo = repo { try? FileManager.default.removeItem(at: repo) }
        try super.tearDownWithError()
    }

    private func writeManifest(version: Int) throws {
        let dir = repo.appendingPathComponent(".kujto")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let json = "{\"syncFormatVersion\":\(version)}"
        try json.write(to: dir.appendingPathComponent("manifest.json"), atomically: true, encoding: .utf8)
    }

    func testManifestMissingThenInitialized() throws {
        XCTAssertEqual(try store.loadManifest(), .missing)
        let load = try store.ensureInitialized()
        XCTAssertEqual(load, .ok(SyncManifest()))
        // A registry file now exists and reads back empty.
        XCTAssertTrue(try store.loadRegistry().projects.isEmpty)
    }

    func testTooNewIsRefused() throws {
        try writeManifest(version: SyncFormat.current + 1)
        XCTAssertEqual(try store.loadManifest(), .tooNew(version: SyncFormat.current + 1))
        // ensureInitialized must not clobber a newer repo.
        XCTAssertEqual(try store.ensureInitialized(), .tooNew(version: SyncFormat.current + 1))
    }

    func testNeedsMigrationStampsCurrent() throws {
        try writeManifest(version: 0)
        XCTAssertEqual(try store.loadManifest(), .needsMigration(from: 0))
        XCTAssertEqual(try store.ensureInitialized(), .ok(SyncManifest()))
        XCTAssertEqual(try store.loadManifest(), .ok(SyncManifest()))
    }

    func testRegistryRoundTripIsSorted() throws {
        var registry = ProjectRegistry()
        registry.upsert(RegisteredProject(name: "Zeta", remote: "git@x:z.git", wiredAgents: ["codex", "claude"]))
        registry.upsert(RegisteredProject(name: "Alpha", remote: "git@x:a.git"))
        try store.saveRegistry(registry)

        let loaded = try store.loadRegistry()
        XCTAssertEqual(loaded.projects.map { $0.name }, ["Alpha", "Zeta"])
        XCTAssertEqual(loaded.projects[1].wiredAgents, ["claude", "codex"])
    }

    func testSaveIsByteStableAcrossReorder() throws {
        let a = RegisteredProject(name: "Alpha", remote: "git@x:a.git")
        let z = RegisteredProject(name: "Zeta", remote: "git@x:z.git")

        try store.saveRegistry(ProjectRegistry(projects: [a, z]))
        let first = try Data(contentsOf: repo.appendingPathComponent("registry.json"))
        try store.saveRegistry(ProjectRegistry(projects: [z, a]))
        let second = try Data(contentsOf: repo.appendingPathComponent("registry.json"))

        // Same logical set in a different order must serialize identically, so
        // the synced registry does not churn.
        XCTAssertEqual(first, second)
    }

    func testLoadRegistryMissingIsEmpty() throws {
        XCTAssertTrue(try store.loadRegistry().projects.isEmpty)
    }
}
