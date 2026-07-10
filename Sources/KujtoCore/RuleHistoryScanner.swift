import Foundation

/// Phase 4 of the Repository Intelligence OS: Governance Rewind.
///
/// Answers "why does this rule exist, and how did it change" from local git
/// alone. For a memory or skill file it walks the commits that touched it and,
/// at each revision, reads the frontmatter so the timeline shows when the rule
/// appeared, when its `risk` tags changed, and when its `applies_to` globs
/// changed. No external service; the whole story is in the repo.
public struct RuleRevision: Sendable, Equatable, Codable {
    /// Short commit hash.
    public let commit: String
    public let author: String
    /// Authored date, `YYYY-MM-DD`.
    public let date: String
    public let subject: String
    /// `risk` frontmatter as of this revision.
    public let risk: [String]
    /// `applies_to` globs as of this revision.
    public let appliesTo: [String]

    public init(commit: String, author: String, date: String, subject: String, risk: [String], appliesTo: [String]) {
        self.commit = commit
        self.author = author
        self.date = date
        self.subject = subject
        self.risk = risk
        self.appliesTo = appliesTo
    }
}

public enum RuleHistoryScanner {

    /// Field separator for `git log --format`. The unit-separator control char
    /// never appears in author names or commit subjects, so splitting on it is
    /// safe where splitting on spaces or tabs is not.
    private static let sep = "\u{1f}"

    /// Revisions of `relativePath`, newest first. Each carries the rule's
    /// frontmatter at that commit so a consumer can see risk and glob drift.
    /// Empty when `root` is not a git repo or the file has no history.
    public static func history(
        forRule relativePath: String,
        in root: URL,
        limit: Int = 50,
        runner: ProcessRunner = ProcessRunner()
    ) -> [RuleRevision] {
        guard let log = try? runner.run(
            "git",
            arguments: [
                "-C", root.path, "log",
                "--format=%h\(sep)%an\(sep)%ad\(sep)%s",
                "--date=short",
                "-n", String(limit),
                "--", relativePath
            ]
        ), log.exitCode == 0 else {
            return []
        }

        return parseLog(log.stdout).map { entry in
            let content = (try? runner.run(
                "git",
                arguments: ["-C", root.path, "show", "\(entry.commit):\(relativePath)"]
            ))?.stdout ?? ""
            let frontmatter = RuleIndex.extractFrontmatter(content)
            return RuleRevision(
                commit: entry.commit,
                author: entry.author,
                date: entry.date,
                subject: entry.subject,
                risk: frontmatter["risk"] ?? [],
                appliesTo: frontmatter["applies_to"] ?? []
            )
        }
    }

    /// Parses `git log --format=%h<US>%an<US>%ad<US>%s` output into fields.
    /// Malformed lines (too few separators) are skipped.
    static func parseLog(_ output: String) -> [(commit: String, author: String, date: String, subject: String)] {
        var out: [(String, String, String, String)] = []
        for rawLine in output.split(separator: "\n", omittingEmptySubsequences: true) {
            let parts = String(rawLine).components(separatedBy: sep)
            guard parts.count >= 4 else { continue }
            // Rejoin any trailing pieces so a subject containing the separator
            // (vanishingly rare) still reads whole.
            let subject = parts[3...].joined(separator: sep)
            out.append((parts[0], parts[1], parts[2], subject))
        }
        return out
    }

    /// Convenience for the timeline: adjacent revisions where the risk tags or
    /// the applies_to globs changed. `history` is newest-first, so each returned
    /// pair reads (newer, older).
    public static func changePoints(in history: [RuleRevision]) -> [(newer: RuleRevision, older: RuleRevision)] {
        guard history.count >= 2 else { return [] }
        var out: [(RuleRevision, RuleRevision)] = []
        for i in 0..<(history.count - 1) {
            let newer = history[i]
            let older = history[i + 1]
            if Set(newer.risk) != Set(older.risk) || Set(newer.appliesTo) != Set(older.appliesTo) {
                out.append((newer, older))
            }
        }
        return out
    }
}
