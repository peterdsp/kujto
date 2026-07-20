import Foundation
import KujtoGit

/// The result of one sync tick. The coordinator maps this to a `SyncStatus`
/// for the menu-bar glyph and, for `.conflict` and `.blockedBySecret`, raises
/// the one card the loop is allowed to interrupt with.
public enum SyncOutcome: Equatable, Sendable {
    /// Nothing to commit and the remote was in sync (or nothing to pull).
    case clean
    /// Committed locally; no upstream is configured, so nothing was pushed.
    case localOnly
    /// Local commits reached the remote.
    case pushed
    /// Committed locally but the remote was unreachable; will retry later.
    case pushDeferred
    /// A rebase stopped on a same-line clash. Carries the unmerged paths.
    case conflict([String])
    /// The secret guard refused to commit. Carries what it found.
    case blockedBySecret([SecretHit])
}

/// What the menu-bar surface shows. No modal ever fires for the first four;
/// `needsAttention` is the only state that pairs with a card.
public enum SyncStatus: String, Sendable {
    case idle
    case syncing
    case synced
    case offline
    case needsAttention

    /// The resting status implied by a completed tick.
    public static func from(_ outcome: SyncOutcome) -> SyncStatus {
        switch outcome {
        case .clean, .localOnly, .pushed: return .synced
        case .pushDeferred: return .offline
        case .conflict, .blockedBySecret: return .needsAttention
        }
    }
}

/// Builds the auto-commit message from the changed paths. Deterministic and
/// pure so it can be unit tested and so two machines generate stable messages.
public enum CommitMessageBuilder {
    /// For example `memory: update rules/tca.md, skills/proto.md (2 files)`.
    /// Beyond `maxNamed` files it summarizes the tail as `and K more`.
    public static func message(for changes: [GitChange], maxNamed: Int = 3) -> String {
        let paths = orderedPaths(changes)
        guard !paths.isEmpty else { return "memory: sync" }

        let count = paths.count
        let unit = count == 1 ? "file" : "files"
        let named: String
        if count <= maxNamed {
            named = paths.joined(separator: ", ")
        } else {
            let head = paths.prefix(maxNamed).joined(separator: ", ")
            named = "\(head) and \(count - maxNamed) more"
        }
        return "memory: update \(named) (\(count) \(unit))"
    }

    /// Distinct live paths, sorted for a stable message across machines.
    private static func orderedPaths(_ changes: [GitChange]) -> [String] {
        var seen = Set<String>()
        var ordered: [String] = []
        for path in changes.map({ $0.path }).sorted() where !seen.contains(path) {
            seen.insert(path)
            ordered.append(path)
        }
        return ordered
    }
}
