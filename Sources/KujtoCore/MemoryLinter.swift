import Foundation

/// Static checks over a repo's Kujto memory. Deterministic, no AI: the linter
/// catches the failure modes that bite when memory drifts away from the code.
///
/// Checks:
///   - missing_agents_file  (error)   no AGENTS.md at the root
///   - missing_memory_index (warning) no memory/MEMORY.md
///   - unmatched_glob       (warning) applies_to glob that matches no file
///   - broken_link          (warning) [[name]] referencing an unknown rule
public struct LintIssue: Sendable, Equatable {
    public enum Severity: String, Sendable { case warning, error }

    public let severity: Severity
    public let code: String
    /// Repo-relative path of the offending file, or empty for repo-wide checks.
    public let file: String
    public let message: String

    public init(severity: Severity, code: String, file: String, message: String) {
        self.severity = severity
        self.code = code
        self.file = file
        self.message = message
    }
}

public enum MemoryLinter {
    public static func lint(root: URL) throws -> [LintIssue] {
        let fm = FileManager.default
        var issues: [LintIssue] = []

        if !fm.fileExists(atPath: root.appendingPathComponent("AGENTS.md").path) {
            issues.append(LintIssue(
                severity: .error,
                code: "missing_agents_file",
                file: "AGENTS.md",
                message: "AGENTS.md is missing at the repo root."
            ))
        }
        if !fm.fileExists(atPath: root.appendingPathComponent("memory/MEMORY.md").path) {
            issues.append(LintIssue(
                severity: .warning,
                code: "missing_memory_index",
                file: "memory/MEMORY.md",
                message: "memory/MEMORY.md is missing. Agents read this index first."
            ))
        }

        let index = try RuleIndex.load(root: root)
        let allFiles = Self.allRepoFiles(root: root)
        let knownSlugs: Set<String> = Set(index.rules.map { Self.slug(forRulePath: $0.path) })

        for rule in index.rules {
            for glob in rule.appliesTo where !allFiles.contains(where: { Glob.matches(glob, path: $0) }) {
                issues.append(LintIssue(
                    severity: .warning,
                    code: "unmatched_glob",
                    file: rule.path,
                    message: "applies_to glob \(glob) matches no file in the repo."
                ))
            }
            if let text = try? String(contentsOf: root.appendingPathComponent(rule.path), encoding: .utf8) {
                for name in Self.wikiLinks(in: text) where !knownSlugs.contains(name) {
                    issues.append(LintIssue(
                        severity: .warning,
                        code: "broken_link",
                        file: rule.path,
                        message: "[[\(name)]] references an unknown memory or skill slug."
                    ))
                }
            }
        }

        issues.sort {
            $0.file != $1.file ? $0.file < $1.file : $0.code < $1.code
        }
        return issues
    }

    static func slug(forRulePath path: String) -> String {
        let last = (path as NSString).lastPathComponent
        let stem = (last as NSString).deletingPathExtension
        // Skill files are conventionally named SKILL.md inside a slug folder.
        if stem.uppercased() == "SKILL" {
            let parent = ((path as NSString).deletingLastPathComponent as NSString).lastPathComponent
            return parent
        }
        return stem
    }

    static func wikiLinks(in text: String) -> [String] {
        let pattern = try? NSRegularExpression(pattern: "\\[\\[([a-zA-Z0-9_\\-/]+)\\]\\]")
        guard let pattern else { return [] }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return pattern.matches(in: text, range: range).compactMap { m in
            guard m.numberOfRanges > 1, let r = Range(m.range(at: 1), in: text) else { return nil }
            return String(text[r])
        }
    }

    /// Walks the repo for files the rule globs would plausibly target. Skips
    /// `.git`, `.build`, and `DerivedData` so we never flag globs as unmatched
    /// because we ignored a build artifact.
    private static func allRepoFiles(root: URL) -> [String] {
        let fm = FileManager.default
        let rootPath = root.resolvingSymlinksInPath().path
        guard let walker = fm.enumerator(at: root, includingPropertiesForKeys: nil) else { return [] }
        var out: [String] = []
        for case let url as URL in walker {
            let path = url.resolvingSymlinksInPath().path
            if path.contains("/.git/") || path.contains("/.build/") || path.contains("/DerivedData/") { continue }
            guard (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true else { continue }
            let rel = path.hasPrefix(rootPath + "/") ? String(path.dropFirst(rootPath.count + 1)) : path
            out.append(rel)
        }
        return out
    }
}
