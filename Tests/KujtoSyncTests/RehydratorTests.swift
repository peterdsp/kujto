import XCTest
@testable import KujtoSync
import KujtoGit
import KujtoCore

/// Rehydrate turns a synced registry into a per-machine plan. The planner is
/// pure, so most tests assert on the plan; a couple exercise execution against
/// real temp repos to prove clone and wire actually run.
final class RehydratorTests: XCTestCase {
    private let rehydrator = Rehydrator()
    private var home: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        home = FileManager.default.temporaryDirectory
            .appendingPathComponent("kujto-home-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let home = home { try? FileManager.default.removeItem(at: home) }
        try super.tearDownWithError()
    }

    private var machine: MachineContext { MachineContext(home: home) }

    @discardableResult
    private func git(_ args: [String], in repo: URL) throws -> String {
        let result = try ProcessRunner().run("git", arguments: ["-C", repo.path] + args)
        XCTAssertEqual(result.exitCode, 0, "git \(args.joined(separator: " ")): \(result.stderr)")
        return result.stdout
    }

    /// A committed source repo the rehydrator can clone from, standing in for a
    /// GitHub remote.
    private func makeSourceRepo(named name: String) throws -> URL {
        let repo = home.appendingPathComponent("remotes/\(name)")
        try FileManager.default.createDirectory(at: repo, withIntermediateDirectories: true)
        try git(["init", "-b", "main"], in: repo)
        try git(["config", "user.name", "Test"], in: repo)
        try git(["config", "user.email", "t@kujto.dev"], in: repo)
        try git(["config", "commit.gpgsign", "false"], in: repo)
        try "x\n".write(to: repo.appendingPathComponent("f.md"), atomically: true, encoding: .utf8)
        try git(["add", "-A"], in: repo)
        try git(["commit", "-m", "seed"], in: repo)
        return repo
    }

    // MARK: Planning

    func testResolveTildeExpansion() {
        let home = URL(fileURLWithPath: "/Users/ada")
        XCTAssertEqual(Rehydrator.resolve(hint: "~", home: home).path, "/Users/ada")
        XCTAssertEqual(Rehydrator.resolve(hint: "~/git/x", home: home).path, "/Users/ada/git/x")
        XCTAssertEqual(Rehydrator.resolve(hint: "/opt/y", home: home).path, "/opt/y")
    }

    func testPlanClonesWhenAbsent() {
        let registry = ProjectRegistry(projects: [
            RegisteredProject(name: "Syrmos", remote: "git@x:s.git",
                              wiredAgents: ["claude"], localPathHint: "~/git/Syrmos")
        ])
        let plan = rehydrator.plan(for: registry, on: machine)
        guard case let .clone(remote, path, agents) = plan.actions.first else {
            return XCTFail("expected clone, got \(plan.actions)")
        }
        XCTAssertEqual(remote, "git@x:s.git")
        XCTAssertEqual(path, Rehydrator.resolve(hint: "~/git/Syrmos", home: home))
        XCTAssertEqual(agents, ["claude"])
    }

    func testPlanSkipsWhenNoHint() {
        let registry = ProjectRegistry(projects: [
            RegisteredProject(name: "NoHint", remote: "git@x:n.git", localPathHint: nil)
        ])
        let plan = rehydrator.plan(for: registry, on: machine)
        XCTAssertEqual(plan.actions.first, .skipNoHint(name: "NoHint", remote: "git@x:n.git"))
        XCTAssertTrue(plan.actionable.isEmpty)
    }

    func testPlanReWiresWhenPresentAndMatching() throws {
        // Clone a source into the hinted location so it is present with the
        // right remote.
        let source = try makeSourceRepo(named: "present")
        let dest = Rehydrator.resolve(hint: "~/git/Present", home: home)
        try ShellGitClient().clone(source.path, to: dest)

        let registry = ProjectRegistry(projects: [
            RegisteredProject(name: "Present", remote: source.path,
                              wiredAgents: ["codex"], localPathHint: "~/git/Present")
        ])
        let plan = rehydrator.plan(for: registry, on: machine)
        XCTAssertEqual(plan.actions.first, .reWire(path: dest, agents: ["codex"]))
    }

    func testPlanSkipsConflictingPath() throws {
        // A directory exists at the hint but is not the registered repo.
        let dest = Rehydrator.resolve(hint: "~/git/Occupied", home: home)
        try FileManager.default.createDirectory(at: dest, withIntermediateDirectories: true)
        try "not a repo".write(to: dest.appendingPathComponent("readme"), atomically: true, encoding: .utf8)

        let registry = ProjectRegistry(projects: [
            RegisteredProject(name: "Occupied", remote: "git@x:o.git", localPathHint: "~/git/Occupied")
        ])
        let plan = rehydrator.plan(for: registry, on: machine)
        guard case let .skipConflicting(path, expected, found) = plan.actions.first else {
            return XCTFail("expected skipConflicting, got \(plan.actions)")
        }
        XCTAssertEqual(path, dest)
        XCTAssertEqual(expected, "git@x:o.git")
        XCTAssertNil(found)
    }

    // MARK: Execution

    func testExecuteClonesAndWires() throws {
        let source = try makeSourceRepo(named: "exec")
        let registry = ProjectRegistry(projects: [
            RegisteredProject(name: "Exec", remote: source.path,
                              wiredAgents: ["claude"], localPathHint: "~/git/Exec")
        ])
        let plan = rehydrator.plan(for: registry, on: machine)

        var wired: [(URL, [String])] = []
        let results = rehydrator.execute(plan) { path, agents in
            wired.append((path, agents))
        }

        let expectedPath = Rehydrator.resolve(hint: "~/git/Exec", home: home)
        XCTAssertEqual(results, [.cloned(path: expectedPath)])
        XCTAssertTrue(ShellGitClient().isRepository(expectedPath))
        XCTAssertEqual(wired.count, 1)
        XCTAssertEqual(wired.first?.1, ["claude"])
    }

    func testExecuteSkipsAreReported() throws {
        let registry = ProjectRegistry(projects: [
            RegisteredProject(name: "NoHint", remote: "git@x:n.git", localPathHint: nil)
        ])
        let plan = rehydrator.plan(for: registry, on: machine)
        let results = rehydrator.execute(plan) { _, _ in XCTFail("wire should not run for a skip") }
        guard case .skipped = results.first else {
            return XCTFail("expected skipped, got \(results)")
        }
    }
}
