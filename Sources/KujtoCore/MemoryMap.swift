import Foundation

/// The memory map of a repo: the aggregate the Kujto Studio sidebar renders and
/// the scanner produces. It is a deterministic snapshot built from `RuleIndex`
/// plus a few presence checks, no AI involved.
public struct MemoryMap: Sendable, Equatable {
    public let root: String
    /// `AGENTS.md` exists at the root (the governance source of truth).
    public let hasAgentsFile: Bool
    /// `memory/MEMORY.md` exists (the human index).
    public let hasMemoryIndex: Bool
    /// File-scoped rules (those with `applies_to` globs).
    public let scopedRules: [Rule]
    /// Base memory: rules read every session (no `applies_to`).
    public let baseRules: [Rule]
    /// Unique `risk` tags across the scoped rules, sorted.
    public let riskTags: [String]

    public init(
        root: String,
        hasAgentsFile: Bool,
        hasMemoryIndex: Bool,
        scopedRules: [Rule],
        baseRules: [Rule],
        riskTags: [String]
    ) {
        self.root = root
        self.hasAgentsFile = hasAgentsFile
        self.hasMemoryIndex = hasMemoryIndex
        self.scopedRules = scopedRules
        self.baseRules = baseRules
        self.riskTags = riskTags
    }

    public var skillCount: Int { (scopedRules + baseRules).filter { $0.kind == .skill }.count }
    public var memoryCount: Int { (scopedRules + baseRules).filter { $0.kind == .memory }.count }
}

public enum MemoryMapScanner {
    /// Builds the map for the repo at `root`.
    public static func scan(root: URL) throws -> MemoryMap {
        let index = try RuleIndex.load(root: root)
        let fm = FileManager.default

        let hasAgents = fm.fileExists(atPath: root.appendingPathComponent("AGENTS.md").path)
        let hasIndex = fm.fileExists(atPath: root.appendingPathComponent("memory/MEMORY.md").path)

        let scoped = index.rules
            .filter { !$0.appliesTo.isEmpty }
            .sorted { $0.path < $1.path }
        let base = index.alwaysOn.sorted { $0.path < $1.path }
        let risks = Set(scoped.flatMap { $0.risk }).sorted()

        return MemoryMap(
            root: root.path,
            hasAgentsFile: hasAgents,
            hasMemoryIndex: hasIndex,
            scopedRules: scoped,
            baseRules: base,
            riskTags: risks
        )
    }
}
