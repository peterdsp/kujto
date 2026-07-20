import Foundation
import KujtoCore
import KujtoGit

/// The history-and-rules cross-link. It answers both directions the design
/// calls for:
///
/// - Click a rule, see the commits that shaped it (delegated to
///   `RuleHistoryScanner`, which also carries the risk and glob drift).
/// - Click a commit, see which rules it touched (the reverse, built here from
///   the commit's changed files intersected with the rule index).
///
/// Pure composition over `RuleHistoryScanner`, `GitClient`, and `RuleIndex`; no
/// new history parsing.
public struct HistoryLinker: Sendable {
    private let client: GitClient
    private let rules: [Rule]
    private let root: URL

    /// A snapshot of the rules is held (not the `RuleIndex`) so the linker is
    /// `Sendable` and can run on a background actor when precomputing which
    /// commits touch rules.
    public init(client: GitClient, rules: [Rule], root: URL) {
        self.client = client
        self.rules = rules
        self.root = root
    }

    /// Convenience: take the rules from an index.
    public init(client: GitClient, index: RuleIndex, root: URL) {
        self.init(client: client, rules: index.rules, root: root)
    }

    /// Revisions of a rule file, newest first, each with its frontmatter at that
    /// commit so a timeline can show when risk or globs changed.
    public func revisions(forRule rulePath: String) -> [RuleRevision] {
        RuleHistoryScanner.history(forRule: rulePath, in: root)
    }

    /// The rules a commit touched: its changed files intersected with the rule
    /// index, so a commit row can show "this changed 2 rules (payment audit,
    /// TCA)".
    public func rules(inCommit sha: String) -> [Rule] {
        let changed = Set((try? client.changedFiles(inCommit: sha, in: root)) ?? [])
        guard !changed.isEmpty else { return [] }
        return rules
            .filter { changed.contains($0.path) }
            .sorted { $0.path < $1.path }
    }

    /// Whether a commit touched any rule at all, for cheaply flagging
    /// governance-relevant commits in the history list.
    public func touchesRules(_ sha: String) -> Bool {
        !rules(inCommit: sha).isEmpty
    }
}
