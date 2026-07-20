import Foundation

/// One project the user has wired Kujto into. Synced in `registry.json` so a
/// new machine knows what working set to offer to rehydrate. The `remote` is
/// the stable identity (a repo clones to different paths on different machines,
/// but its remote is constant); the path is only a `localPathHint`, never an
/// absolute path, because it means nothing on another machine.
public struct RegisteredProject: Codable, Equatable, Sendable {
    public var name: String
    public var remote: String
    public var wiredAgents: [String]
    public var localPathHint: String?
    public var ruleOverrides: [String]

    public init(name: String, remote: String, wiredAgents: [String] = [],
                localPathHint: String? = nil, ruleOverrides: [String] = []) {
        self.name = name
        self.remote = remote
        self.wiredAgents = wiredAgents
        self.localPathHint = localPathHint
        self.ruleOverrides = ruleOverrides
    }

    /// Sorted arrays so re-saving the same logical state produces byte-identical
    /// JSON, which keeps the synced `registry.json` from generating spurious
    /// diffs and conflicts.
    func normalized() -> RegisteredProject {
        var copy = self
        copy.wiredAgents = Array(Set(wiredAgents)).sorted()
        copy.ruleOverrides = Array(Set(ruleOverrides)).sorted()
        return copy
    }

    /// Turns an absolute local path into a home-relative hint (`~/...`) when it
    /// lives under `home`, so the stored value is portable. Paths outside home
    /// are stored verbatim.
    public static func hint(forLocalPath path: URL, home: URL) -> String {
        let p = path.standardizedFileURL.path
        let h = home.standardizedFileURL.path
        if p == h { return "~" }
        if p.hasPrefix(h + "/") {
            return "~/" + String(p.dropFirst(h.count + 1))
        }
        return p
    }
}

/// The set of projects in the synced memory repo. Upsert is keyed on `remote`
/// so re-wiring the same repo updates its entry instead of duplicating it.
public struct ProjectRegistry: Codable, Equatable, Sendable {
    public var projects: [RegisteredProject]

    public init(projects: [RegisteredProject] = []) {
        self.projects = projects
    }

    /// Insert or replace by remote identity.
    public mutating func upsert(_ project: RegisteredProject) {
        if let index = projects.firstIndex(where: { $0.remote == project.remote }) {
            projects[index] = project
        } else {
            projects.append(project)
        }
    }

    /// Remove the entry with this remote, if present.
    public mutating func remove(remote: String) {
        projects.removeAll { $0.remote == remote }
    }

    /// Look up by remote.
    public func project(withRemote remote: String) -> RegisteredProject? {
        projects.first { $0.remote == remote }
    }

    /// Projects sorted by name with each entry normalized, for a stable,
    /// diff-friendly on-disk form.
    public func normalized() -> ProjectRegistry {
        ProjectRegistry(projects: projects.map { $0.normalized() }.sorted { $0.name < $1.name })
    }
}
