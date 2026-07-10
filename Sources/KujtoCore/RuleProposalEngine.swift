import Foundation

/// Phase 5 of the Repository Intelligence OS: Generative Memory, the safe way.
///
/// The doc's hard guardrail: never auto-write AGENTS.md or memory files from a
/// model. So this engine is deterministic and proposes only. It finds groups of
/// source files that share an architectural role (all the Reducers, all the
/// Clients) but have no scoped rule covering them, and drafts a reviewable
/// memory file with candidate `applies_to` globs and a rationale. A human reads,
/// edits, and adopts it. Kujto writes nothing into memory on its own.
public struct RuleProposal: Sendable, Equatable {
    /// Human title for the proposed rule.
    public let title: String
    /// Candidate `applies_to` globs.
    public let appliesTo: [String]
    /// Why Kujto proposes this, in one sentence.
    public let rationale: String
    /// Repo-relative source files the proposal would cover.
    public let affectedFiles: [String]
    /// Suggested (not written) location under a proposals area.
    public let suggestedPath: String
    /// Ready-to-review Markdown, frontmatter included. Adopting = a human moves
    /// this into memory/ after editing.
    public let draftMarkdown: String

    public init(
        title: String,
        appliesTo: [String],
        rationale: String,
        affectedFiles: [String],
        suggestedPath: String,
        draftMarkdown: String
    ) {
        self.title = title
        self.appliesTo = appliesTo
        self.rationale = rationale
        self.affectedFiles = affectedFiles
        self.suggestedPath = suggestedPath
        self.draftMarkdown = draftMarkdown
    }
}

public enum RuleProposalEngine {

    /// Architectural suffixes that tend to carry their own conventions. A group
    /// of files sharing one of these is a natural unit for a scoped rule.
    static let roleSuffixes = [
        "Reducer", "Feature", "Store", "View", "Screen", "Client",
        "Service", "Repository", "Coordinator", "ViewModel", "Presenter", "Controller"
    ]

    /// Proposes scoped rules for role groups of at least `minFiles` files that
    /// no existing scoped rule covers. Deterministic; writes nothing.
    public static func propose(in root: URL, minFiles: Int = 3) throws -> [RuleProposal] {
        let index = try RuleIndex.load(root: root)
        let files = sourceFiles(under: root)

        var buckets: [String: [String]] = [:]
        for file in files {
            let stem = ((file as NSString).lastPathComponent as NSString).deletingPathExtension
            for suffix in roleSuffixes where stem.hasSuffix(suffix) && stem != suffix {
                buckets[suffix, default: []].append(file)
            }
        }

        var proposals: [RuleProposal] = []
        for suffix in roleSuffixes {
            guard let group = buckets[suffix], group.count >= minFiles else { continue }
            let glob = "**/*\(suffix).swift"
            if isCovered(files: group, glob: glob, by: index) { continue }
            proposals.append(makeProposal(suffix: suffix, glob: glob, files: group.sorted()))
        }

        return proposals.sorted { $0.affectedFiles.count > $1.affectedFiles.count }
    }

    /// A group is covered when its candidate glob already exists on a rule, or
    /// when existing scoped rules already match at least half the group.
    static func isCovered(files: [String], glob: String, by index: RuleIndex) -> Bool {
        for rule in index.rules where rule.appliesTo.contains(glob) { return true }
        let matched = files.filter { file in
            !index.resolve(file: file).isEmpty
        }.count
        return matched * 2 >= files.count
    }

    static func makeProposal(suffix: String, glob: String, files: [String]) -> RuleProposal {
        let title = "Rules for \(suffix) files"
        let rationale = "\(files.count) \(suffix) file(s) share a role but no scoped rule covers them."
        let path = "memory/proposed/\(suffix.lowercased()).md"
        let sample = files.prefix(5).map { "  - \($0)" }.joined(separator: "\n")
        let draft = """
        ---
        applies_to:
          - "\(glob)"
        risk:
        ---
        # \(title)

        <!-- Proposed by Kujto from \(files.count) matching files with no scoped rule.
             Review and edit this, then move it into memory/ to adopt. Kujto never
             writes memory for you. Fill in `risk:` if these files are load-bearing. -->

        What an agent must know before editing a \(suffix) in this repo:

        - (describe the conventions, invariants, and traps here)

        Matched files (sample):
        \(sample)
        """
        return RuleProposal(
            title: title,
            appliesTo: [glob],
            rationale: rationale,
            affectedFiles: files,
            suggestedPath: path,
            draftMarkdown: draft
        )
    }

    /// Repo-relative `.swift` source paths, skipping build artifacts and the
    /// memory/skills trees (rules are inputs, not files under governance).
    private static func sourceFiles(under root: URL) -> [String] {
        let fm = FileManager.default
        let rootPath = root.resolvingSymlinksInPath().path
        guard let walker = fm.enumerator(at: root, includingPropertiesForKeys: [.isRegularFileKey]) else { return [] }

        var out: [String] = []
        for case let url as URL in walker where url.pathExtension == "swift" {
            let path = url.resolvingSymlinksInPath().path
            if path.contains("/.git/") || path.contains("/.build/") || path.contains("/DerivedData/") { continue }
            let rel = path.hasPrefix(rootPath + "/") ? String(path.dropFirst(rootPath.count + 1)) : path
            if rel.hasPrefix("memory/") || rel.hasPrefix("skills/") { continue }
            out.append(rel)
        }
        return out
    }
}
