import Foundation

/// Phase 3 of the Repository Intelligence OS: the Agent Sandbox pre-flight.
///
/// Before an agent (or a human) edits a file, Kujto assembles everything the
/// change needs to be safe: the rules that apply, the risk verdict, the tests
/// that should pass, the context that is missing, and a ready-to-paste prompt.
/// It grades readiness and, on request, spins up a throwaway git worktree so a
/// dry-run touches nothing in the real tree until a human reviews the diff.
///
/// Deterministic and local. No model calls: the "prompt" is assembled from
/// memory metadata, not generated.
public struct AgentPreflight: Sendable, Equatable {
    public enum Readiness: String, Sendable {
        case ready
        case needsContext
        case blocked

        public var label: String {
            switch self {
            case .ready: return "Ready"
            case .needsContext: return "Needs context"
            case .blocked: return "Blocked"
            }
        }
    }

    public let file: String
    public let readiness: Readiness
    /// 0...100, higher is more ready. Inverse of risk, docked for missing context.
    public let readinessScore: Int
    /// The underlying risk verdict for the file.
    public let risk: RiskScore
    /// Repo-relative paths of the memory/skill rules that govern this file.
    public let matchedRulePaths: [String]
    /// Sibling test files that should pass after the change.
    public let suggestedTests: [String]
    /// Gaps a reviewer should close before trusting an agent here.
    public let missingContext: [String]
    /// A deterministic, paste-ready pre-flight brief for an agent.
    public let prompt: String

    public init(
        file: String,
        readiness: Readiness,
        readinessScore: Int,
        risk: RiskScore,
        matchedRulePaths: [String],
        suggestedTests: [String],
        missingContext: [String],
        prompt: String
    ) {
        self.file = file
        self.readiness = readiness
        self.readinessScore = readinessScore
        self.risk = risk
        self.matchedRulePaths = matchedRulePaths
        self.suggestedTests = suggestedTests
        self.missingContext = missingContext
        self.prompt = prompt
    }
}

public enum AgentSandbox {

    // MARK: - Pre-flight

    /// Assembles the pre-flight for `file` in `root`. `changedFiles` lets the
    /// risk step weight an in-progress edit.
    public static func preflight(
        file relativePath: String,
        in root: URL,
        changedFiles: Set<String> = []
    ) throws -> AgentPreflight {
        let index = try RuleIndex.load(root: root)
        let matches = index.resolve(file: relativePath)

        let conflicts = ConflictLens.detect(in: index)
        let matchedRulePaths = Set(matches.map { $0.rule.path })
        let fileConflicts = conflicts.filter {
            matchedRulePaths.contains($0.first.path) || matchedRulePaths.contains($0.second.path)
        }

        let tests = RelatedTests.testsFor(file: relativePath, in: root)
        let hasRiskRule = matches.contains { !$0.rule.risk.isEmpty }

        let risk = RiskScorer.score(RiskScorer.FileInput(
            path: relativePath,
            matches: matches,
            lint: [],
            conflicts: fileConflicts,
            relatedTestCount: tests.count,
            isDirty: changedFiles.contains(relativePath)
        ))

        // Missing-context gaps a reviewer should close first.
        var gaps: [String] = []
        if matches.isEmpty {
            gaps.append("No file-scoped rules match this path; only base memory applies.")
        }
        if hasRiskRule && tests.isEmpty {
            gaps.append("This is a risk-tagged file with no sibling tests to verify a change.")
        }
        if !fileConflicts.isEmpty {
            gaps.append("\(fileConflicts.count) unresolved rule conflict(s) touch this file.")
        }
        // Agents that will not see this repo's memory act blind here.
        if let trace = try? MemoryTracer.trace(file: relativePath, in: root) {
            let blind = trace.receivers.filter { $0.state == .notReceiving }
            if !matches.isEmpty && !blind.isEmpty {
                let names = blind.map { $0.agent.displayName }.joined(separator: ", ")
                gaps.append("Not wired for: \(names). They would edit without this context.")
            }
        }

        let readiness = readiness(for: risk.level, gaps: gaps)
        let readinessScore = max(0, min(100, 100 - risk.score - gaps.count * 10))

        let prompt = assemblePrompt(
            file: relativePath,
            repoName: root.lastPathComponent,
            risk: risk,
            matches: matches,
            baseRuleCount: index.alwaysOn.count,
            tests: tests,
            gaps: gaps
        )

        return AgentPreflight(
            file: relativePath,
            readiness: readiness,
            readinessScore: readinessScore,
            risk: risk,
            matchedRulePaths: matches.map { $0.rule.path },
            suggestedTests: tests,
            missingContext: gaps,
            prompt: prompt
        )
    }

    static func readiness(for level: RiskScore.Level, gaps: [String]) -> AgentPreflight.Readiness {
        if level == .blocked { return .blocked }
        if level > .safe || !gaps.isEmpty { return .needsContext }
        return .ready
    }

    /// Builds the deterministic pre-flight brief. Assembled from metadata, not
    /// generated: the same repo state always yields the same text.
    static func assemblePrompt(
        file: String,
        repoName: String,
        risk: RiskScore,
        matches: [RuleMatch],
        baseRuleCount: Int,
        tests: [String],
        gaps: [String]
    ) -> String {
        var lines: [String] = []
        lines.append("You are about to edit \(file) in \(repoName).")
        lines.append("Risk: \(risk.level.label) (\(risk.score)/100). \(risk.headline)")
        lines.append("")

        if matches.isEmpty {
            lines.append("Scoped rules: none. \(baseRuleCount) base memory rule(s) still apply.")
        } else {
            lines.append("Rules that apply (most specific first):")
            for match in matches {
                let riskTag = match.rule.risk.isEmpty ? "" : " [risk: \(match.rule.risk.joined(separator: ", "))]"
                lines.append("  - \(match.rule.title)\(riskTag) (\(match.rule.path)) matched \(match.glob)")
            }
            lines.append("Plus \(baseRuleCount) always-on base memory rule(s).")
        }
        lines.append("")

        if tests.isEmpty {
            lines.append("Tests to run: none found. Add coverage before changing behavior.")
        } else {
            lines.append("Tests to run before finishing:")
            for test in tests { lines.append("  - \(test)") }
        }

        if !gaps.isEmpty {
            lines.append("")
            lines.append("Resolve first:")
            for gap in gaps { lines.append("  - \(gap)") }
        }

        lines.append("")
        lines.append("Work in the sandbox worktree. Do not apply changes to the main tree until a human reviews the diff.")
        return lines.joined(separator: "\n")
    }

    // MARK: - Temporary worktree (dry-run isolation)

    /// A throwaway git worktree for dry-run changes. Removing it discards
    /// everything: the sandbox is where an agent works, never the real tree.
    public struct SandboxWorktree: Sendable {
        public let path: URL
        public let root: URL

        public init(path: URL, root: URL) {
            self.path = path
            self.root = root
        }

        /// Tears the worktree down via `git worktree remove --force`.
        @discardableResult
        public func remove(runner: ProcessRunner = ProcessRunner()) -> Bool {
            let result = try? runner.run(
                "git",
                arguments: ["-C", root.path, "worktree", "remove", "--force", path.path]
            )
            return result?.exitCode == 0
        }
    }

    /// Creates a detached worktree of `root` under the system temp directory.
    /// The caller works there and calls `remove()` when done; nothing in the
    /// real tree is touched. Throws if `root` is not a git repo.
    public static func makeSandbox(
        in root: URL,
        name: String = "preflight",
        runner: ProcessRunner = ProcessRunner()
    ) throws -> SandboxWorktree {
        let safeName = name.replacingOccurrences(of: "/", with: "-")
        let dest = FileManager.default.temporaryDirectory
            .appendingPathComponent("kujto-sandbox-\(safeName)-\(UUID().uuidString)")
        let result = try runner.run(
            "git",
            arguments: ["-C", root.path, "worktree", "add", "--detach", dest.path]
        )
        guard result.exitCode == 0 else {
            throw KujtoError(
                code: .process,
                message: LMsg(
                    sq: "Nuk munda te krijoj worktree sandbox: \(result.stderr)",
                    en: "Could not create sandbox worktree: \(result.stderr)"
                )
            )
        }
        return SandboxWorktree(path: dest, root: root)
    }
}
