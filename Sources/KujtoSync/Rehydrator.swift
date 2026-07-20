import Foundation
import KujtoGit

/// The machine-specific context a plan is resolved against. Injected (rather
/// than reading the real home directory) so planning is pure and testable.
public struct MachineContext: Sendable {
    public let home: URL
    public init(home: URL) { self.home = home }
}

/// What rehydrate proposes to do for a single registered project on this
/// machine. The planner never mutates anything; the UI confirms, then the
/// executor acts. Cloning someone's whole working set without a click would be
/// presumptuous, so this stays a proposal.
public enum RehydrateAction: Equatable, Sendable {
    /// Not present locally: clone the remote to `path`, then wire these agents.
    case clone(remote: String, path: URL, agents: [String])
    /// Already present and matching: just re-wire these agents.
    case reWire(path: URL, agents: [String])
    /// A directory is at `path` but it is a different repo (or not a repo).
    /// Skip and warn rather than touch it.
    case skipConflicting(path: URL, expectedRemote: String, foundRemote: String?)
    /// No `localPathHint`, so we cannot place it without asking. Skip.
    case skipNoHint(name: String, remote: String)

    /// The project name or remote this action concerns, for stable ordering.
    var sortKey: String {
        switch self {
        case let .clone(remote, _, _): return remote
        case let .reWire(path, _): return path.path
        case let .skipConflicting(_, expected, _): return expected
        case let .skipNoHint(_, remote): return remote
        }
    }
}

/// A confirmable rehydrate plan.
public struct RehydratePlan: Equatable, Sendable {
    public let actions: [RehydrateAction]

    /// Actions that would change the machine (clone or re-wire).
    public var actionable: [RehydrateAction] {
        actions.filter {
            switch $0 {
            case .clone, .reWire: return true
            case .skipConflicting, .skipNoHint: return false
            }
        }
    }
}

/// The result of executing one action.
public enum RehydrateResult: Equatable, Sendable {
    case cloned(path: URL)
    case wired(path: URL)
    case skipped(reason: String)
    case failed(path: URL?, message: String)
}

/// Turns a synced registry into a per-machine plan, and (separately) executes a
/// confirmed plan. Planning is pure; execution touches the filesystem and the
/// network and is kept deliberately thin.
public struct Rehydrator: Sendable {
    private let client: GitClient

    public init(client: GitClient = ShellGitClient()) {
        self.client = client
    }

    /// Builds the plan. Deterministic given the same registry, machine, and
    /// on-disk state.
    public func plan(for registry: ProjectRegistry, on machine: MachineContext) -> RehydratePlan {
        let actions = registry.normalized().projects.map { project in
            action(for: project, on: machine)
        }
        return RehydratePlan(actions: actions.sorted { $0.sortKey < $1.sortKey })
    }

    private func action(for project: RegisteredProject, on machine: MachineContext) -> RehydrateAction {
        guard let hint = project.localPathHint else {
            return .skipNoHint(name: project.name, remote: project.remote)
        }
        let path = Self.resolve(hint: hint, home: machine.home)

        if !FileManager.default.fileExists(atPath: path.path) {
            return .clone(remote: project.remote, path: path, agents: project.wiredAgents)
        }
        if client.isRepository(path), let found = client.remoteURL(in: path), found == project.remote {
            return .reWire(path: path, agents: project.wiredAgents)
        }
        return .skipConflicting(path: path, expectedRemote: project.remote,
                                foundRemote: client.isRepository(path) ? client.remoteURL(in: path) : nil)
    }

    /// Executes a confirmed plan. `wire` performs the agent wiring for a path
    /// (in the app this wraps `KujtoCore.Wire`); injected so this stays testable
    /// without touching a real agent home.
    public func execute(_ plan: RehydratePlan, wire: (URL, [String]) throws -> Void) -> [RehydrateResult] {
        plan.actions.map { action in
            switch action {
            case let .clone(remote, path, agents):
                do {
                    try client.clone(remote, to: path)
                    try wire(path, agents)
                    return .cloned(path: path)
                } catch {
                    return .failed(path: path, message: "\(error)")
                }
            case let .reWire(path, agents):
                do {
                    try wire(path, agents)
                    return .wired(path: path)
                } catch {
                    return .failed(path: path, message: "\(error)")
                }
            case let .skipConflicting(path, expected, found):
                return .skipped(reason: "path \(path.lastPathComponent) holds \(found ?? "no repo"), expected \(expected)")
            case let .skipNoHint(name, _):
                return .skipped(reason: "no local path hint for \(name)")
            }
        }
    }

    /// Expands a stored hint against `home`. `~` and `~/x` become home-relative;
    /// anything else is treated as an absolute path. Built from path strings and
    /// `isDirectory: false` so the result never depends on whether the directory
    /// exists yet (an existence check would otherwise add a trailing slash and
    /// make the same path compare unequal before and after a clone).
    static func resolve(hint: String, home: URL) -> URL {
        let raw: String
        if hint == "~" {
            raw = home.path
        } else if hint.hasPrefix("~/") {
            raw = home.appendingPathComponent(String(hint.dropFirst(2))).path
        } else {
            raw = hint
        }
        return URL(fileURLWithPath: raw, isDirectory: false)
    }
}
