import Foundation
import KujtoGit

/// How to resolve a same-line clash. `keepBoth` is the design's default (never
/// lose a rule); the other two let the user pick a side when both cannot stand.
public enum ConflictResolution: Sendable, Equatable {
    /// Keep both bodies, remote first then local. No rule is lost.
    case keepBoth
    /// Keep the version from this machine's just-made commit.
    case keepLocal
    /// Keep the version already on the remote.
    case keepRemote
}

/// Resolves the conflicted files left by a stopped `pull --rebase`, then
/// continues the rebase. Rewrites each file according to the chosen strategy,
/// stages it, and continues; or aborts to restore the pre-sync state.
///
/// In a rebase the `HEAD` side of a conflict marker is the branch being rebased
/// onto (the remote), and the incoming side is this machine's commit (local),
/// so `keepRemote` keeps the top hunk and `keepLocal` the bottom.
public struct ConflictResolver: Sendable {
    private let client: GitClient

    public init(client: GitClient = ShellGitClient()) {
        self.client = client
    }

    /// Rewrites the conflicted files, stages them, and continues the rebase.
    public func resolve(_ resolution: ConflictResolution, files: [String], in repo: URL) throws {
        for path in files {
            let url = repo.appendingPathComponent(path)
            guard let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
            let resolved = Self.resolveText(text, resolution)
            try resolved.write(to: url, atomically: true, encoding: .utf8)
            try client.stage([path], in: repo)
        }
        try client.rebaseContinue(in: repo)
    }

    /// Abandons the rebase, restoring the working tree to before the sync.
    public func abort(in repo: URL) throws {
        try client.rebaseAbort(in: repo)
    }

    /// Rewrites conflict-marked text per the resolution. Handles multiple
    /// conflict hunks in one file. Kept pure and `static` so it is unit
    /// testable without a repo.
    static func resolveText(_ text: String, _ resolution: ConflictResolution) -> String {
        enum Section { case none, ours, theirs }
        var section: Section = .none
        var out: [String] = []
        var ours: [String] = []
        var theirs: [String] = []

        for line in text.components(separatedBy: "\n") {
            if line.hasPrefix("<<<<<<<") {
                section = .ours; ours = []; theirs = []
                continue
            }
            if section == .ours, line.hasPrefix("=======") {
                section = .theirs
                continue
            }
            if section == .theirs, line.hasPrefix(">>>>>>>") {
                switch resolution {
                case .keepBoth: out.append(contentsOf: ours); out.append(contentsOf: theirs)
                case .keepRemote: out.append(contentsOf: ours)   // HEAD side
                case .keepLocal: out.append(contentsOf: theirs)  // incoming side
                }
                section = .none
                continue
            }
            switch section {
            case .none: out.append(line)
            case .ours: ours.append(line)
            case .theirs: theirs.append(line)
            }
        }
        return out.joined(separator: "\n")
    }
}
