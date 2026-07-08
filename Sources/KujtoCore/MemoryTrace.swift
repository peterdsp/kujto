import Foundation

/// The provenance chain for "why would an agent behave this way for THIS file
/// in THIS repo." Produced by `MemoryTracer.trace(file:...)` and rendered by
/// Kujto Studio as a vertical citation column, or by the CLI as prose.
///
/// A trace is a sequence of steps the reader can follow in order. Each step
/// is a discrete cause: a matched glob, a rule read from a source file,
/// which agents receive that rule through their wired path. The final steps
/// are the receivers: agents that will see this memory (Claude via
/// CLAUDE.md, Cursor via .cursorrules, etc.) and - critically - agents that
/// will NOT, because their wire target is missing or diverged.
public struct MemoryTrace: Sendable, Equatable {
    public struct Match: Sendable, Equatable {
        /// Relative path of the memory or skill file (e.g. `memory/ios/tca.md`).
        public let rulePath: String
        /// Human title of the rule from its first heading.
        public let ruleTitle: String
        /// The `applies_to` glob on the rule that actually matched the file.
        public let matchedGlob: String
        /// Higher = more specific. Used to sort matches most-specific-first.
        public let specificity: Int
        /// Risk tags declared in the rule's frontmatter, e.g. `payment`.
        public let risk: [String]

        public init(rulePath: String, ruleTitle: String, matchedGlob: String, specificity: Int, risk: [String]) {
            self.rulePath = rulePath
            self.ruleTitle = ruleTitle
            self.matchedGlob = matchedGlob
            self.specificity = specificity
            self.risk = risk
        }
    }

    public struct Receiver: Sendable, Equatable {
        public enum State: Sendable, Equatable { case receiving, notReceiving }
        public let agent: AgentKind
        public let state: State
        /// One-sentence explanation of the state (e.g. "receives memory
        /// through CLAUDE.md" or "not wired here, Cursor sees nothing").
        public let note: String

        public init(agent: AgentKind, state: State, note: String) {
            self.agent = agent
            self.state = state
            self.note = note
        }
    }

    /// The repo-relative file the trace was computed for.
    public let file: String
    /// Base rules that always apply. Not file-specific; listed for context.
    public let baseRuleCount: Int
    /// Every scoped rule that matched, ranked most-specific-first.
    public let matches: [Match]
    /// Which agents receive this context, and which do not.
    public let receivers: [Receiver]

    public init(file: String, baseRuleCount: Int, matches: [Match], receivers: [Receiver]) {
        self.file = file
        self.baseRuleCount = baseRuleCount
        self.matches = matches
        self.receivers = receivers
    }
}

/// Builds a `MemoryTrace` for a given file.
///
/// Deterministic: no model calls. Uses `RuleIndex.resolve(file:)` for
/// matching and inspects the on-disk agent files (via
/// `FileManés-Aware` reasoning) to decide which agents actually receive
/// the memory in this repo. Agents whose wire target file is missing are
/// reported as `notReceiving`.
public enum MemoryTracer {
    public static func trace(file relativePath: String, in root: URL) throws -> MemoryTrace {
        let index = try RuleIndex.load(root: root)
        let matches = index.resolve(file: relativePath).map {
            MemoryTrace.Match(
                rulePath: $0.rule.path,
                ruleTitle: $0.rule.title,
                matchedGlob: $0.glob,
                specificity: $0.score,
                risk: $0.rule.risk
            )
        }

        // An agent "receives" this memory when its wire-target file exists
        // in the repo. It says nothing about whether that file's contents
        // actually route to the matched rule - Kujto keeps a single source
        // of truth, so if the wire is up, the receiver sees it.
        let fm = FileManager.default
        let receivers = AgentKind.allCases.map { agent -> MemoryTrace.Receiver in
            let target = root.appendingPathComponent(agent.fileName)
            if fm.fileExists(atPath: target.path) {
                return MemoryTrace.Receiver(
                    agent: agent,
                    state: .receiving,
                    note: "receives memory through \(agent.fileName)"
                )
            }
            return MemoryTrace.Receiver(
                agent: agent,
                state: .notReceiving,
                note: "not wired here; \(agent.displayName) sees no repo memory"
            )
        }

        return MemoryTrace(
            file: relativePath,
            baseRuleCount: index.alwaysOn.count,
            matches: matches,
            receivers: receivers
        )
    }
}
