import Foundation

/// Turns the deterministic signals Kujto already computes (scoped rule matches,
/// risk tags, lint findings, conflicts, related tests, and whether the file is
/// mid-edit) into a single graded verdict with a plain-language reason and a
/// ranked cause stack.
///
/// This is the successor to `RuleIndex.confidence(forFile:)`: where confidence
/// answered "safe / needs context / danger zone" from rule matches alone, the
/// scorer folds in lint, conflicts, test coverage, and diff state, and grades
/// the result on a four-step scale so a dashboard can show trend and cause.
///
/// No AI. Every point of the score traces to a listed cause, so the verdict is
/// inspectable and reproducible.
public struct RiskScore: Sendable, Equatable, Codable {
    /// The graded verdict. Ordered from calm to hard-stop so callers can
    /// compare and take the worst across a set of files.
    public enum Level: String, Sendable, Codable, CaseIterable, Comparable {
        case safe
        case watch
        case escalating
        case blocked

        private var order: Int {
            switch self {
            case .safe: return 0
            case .watch: return 1
            case .escalating: return 2
            case .blocked: return 3
            }
        }

        public static func < (lhs: Level, rhs: Level) -> Bool {
            lhs.order < rhs.order
        }

        /// Capitalized badge label, e.g. "Escalating".
        public var label: String {
            rawValue.prefix(1).uppercased() + rawValue.dropFirst()
        }
    }

    /// A single scored contributor to the verdict, surfaced in the cause stack.
    public struct Cause: Sendable, Equatable, Codable {
        /// Short title, e.g. a rule title or "Merge conflict".
        public let title: String
        /// The exact evidence: a glob, a lint message, a risk tag list.
        public let detail: String
        /// How many points this contributor added to the raw score.
        public let weight: Int

        public init(title: String, detail: String, weight: Int) {
            self.title = title
            self.detail = detail
            self.weight = weight
        }
    }

    public let level: Level
    /// Clamped to 0...100. Higher is riskier.
    public let score: Int
    /// One-sentence reason for the badge.
    public let headline: String
    /// The single most useful next step for this verdict.
    public let action: RiskAction
    /// Contributors, most points first (already truncated for display upstream).
    public let causes: [Cause]

    public init(level: Level, score: Int, headline: String, action: RiskAction, causes: [Cause]) {
        self.level = level
        self.score = score
        self.headline = headline
        self.action = action
        self.causes = causes
    }
}

/// The primary next step a verdict points at. One per verdict; the dashboard's
/// "next action row" can offer the rest as secondary options.
public enum RiskAction: String, Sendable, Codable {
    case proceed
    case reviewContext
    case runRelatedTests
    case resolveConflicts
    case addOverrideReason

    /// Button-ready label.
    public var label: String {
        switch self {
        case .proceed: return "Proceed"
        case .reviewContext: return "Review context"
        case .runRelatedTests: return "Run related tests"
        case .resolveConflicts: return "Resolve conflicts"
        case .addOverrideReason: return "Add override reason"
        }
    }
}

/// One file's verdict paired with its path. The path is not part of `RiskScore`
/// itself so the score stays reusable; this pairs them for repo-level views.
public struct FileScore: Sendable, Equatable {
    public let path: String
    public let score: RiskScore

    public init(path: String, score: RiskScore) {
        self.path = path
        self.score = score
    }
}

/// A whole-repo assessment: the rolled-up verdict, every scored file, and the
/// raw counts a snapshot records. Everything `RiskScorer.assess` learned in one
/// pass, so the caller never re-walks the repo to fill a snapshot.
public struct RepoAssessment: Sendable, Equatable {
    public let verdict: RiskScore
    public let files: [FileScore]
    public let lintErrorCount: Int
    public let lintWarningCount: Int
    public let conflictCount: Int

    public init(
        verdict: RiskScore,
        files: [FileScore],
        lintErrorCount: Int,
        lintWarningCount: Int,
        conflictCount: Int
    ) {
        self.verdict = verdict
        self.files = files
        self.lintErrorCount = lintErrorCount
        self.lintWarningCount = lintWarningCount
        self.conflictCount = conflictCount
    }
}

public enum RiskScorer {

    // MARK: - Weights and thresholds
    //
    // Weights are additive points. Thresholds map the clamped raw sum onto the
    // four levels. Tuned so a single risk-tagged rule already lands in `watch`,
    // an in-flight edit to that file reaches `escalating`, and a risky file
    // that is untested, conflicted, and dirty is `blocked`.

    static let scopedRuleWeight = 15   // a scoped rule match with no risk tag
    static let riskRuleWeight = 28     // a scoped rule carrying a risk tag
    static let lintErrorWeight = 30    // a lint error on this file
    static let lintWarningWeight = 8   // a lint warning on this file
    static let conflictWeight = 18     // a structural conflict on a matched rule
    static let untestedRiskWeight = 12 // risk-tagged file with no related tests
    static let dirtyBoost = 18         // file is in the current diff (imminent)

    static let watchThreshold = 12
    static let escalatingThreshold = 40
    static let blockedThreshold = 75

    /// Everything the scorer needs about one file. The caller gathers these
    /// from `RuleIndex.resolve`, `MemoryLinter`, `ConflictLens`, and
    /// `RelatedTests`; the scorer stays pure and re-runnable.
    public struct FileInput: Sendable {
        public let path: String
        /// Scoped rules that matched the file, most specific first.
        public let matches: [RuleMatch]
        /// Lint issues whose `file` is this file.
        public let lint: [LintIssue]
        /// Conflicts that involve one of this file's matched rules.
        public let conflicts: [Conflict]
        /// How many sibling test files were found for this file.
        public let relatedTestCount: Int
        /// True when the file is in the working-tree or staged diff.
        public let isDirty: Bool

        public init(
            path: String,
            matches: [RuleMatch],
            lint: [LintIssue] = [],
            conflicts: [Conflict] = [],
            relatedTestCount: Int = 0,
            isDirty: Bool = false
        ) {
            self.path = path
            self.matches = matches
            self.lint = lint
            self.conflicts = conflicts
            self.relatedTestCount = relatedTestCount
            self.isDirty = isDirty
        }
    }

    // MARK: - Per-file scoring

    public static func score(_ input: FileInput) -> RiskScore {
        var causes: [RiskScore.Cause] = []
        var hasRiskRule = false

        for match in input.matches {
            let rule = match.rule
            if rule.risk.isEmpty {
                causes.append(RiskScore.Cause(
                    title: rule.title,
                    detail: "scoped rule, matches \(match.glob)",
                    weight: scopedRuleWeight
                ))
            } else {
                hasRiskRule = true
                causes.append(RiskScore.Cause(
                    title: rule.title,
                    detail: "risk: \(rule.risk.joined(separator: ", ")) via \(match.glob)",
                    weight: riskRuleWeight
                ))
            }
        }

        for issue in input.lint {
            let weight = issue.severity == .error ? lintErrorWeight : lintWarningWeight
            causes.append(RiskScore.Cause(
                title: "Lint \(issue.severity.rawValue): \(issue.code)",
                detail: issue.message,
                weight: weight
            ))
        }

        // Conflicts are pair-wise; de-duplicate by summary so the same conflict
        // reported from either rule side counts once.
        var seenConflicts: Set<String> = []
        for conflict in input.conflicts where seenConflicts.insert(conflict.summary).inserted {
            causes.append(RiskScore.Cause(
                title: "Conflict",
                detail: conflict.summary,
                weight: conflictWeight
            ))
        }

        if hasRiskRule && input.relatedTestCount == 0 {
            causes.append(RiskScore.Cause(
                title: "No related tests",
                detail: "risk-tagged file has no sibling tests to verify a change",
                weight: untestedRiskWeight
            ))
        }

        // The dirty boost only applies when there is already some risk; editing
        // a file with no rules or issues is not itself risky.
        if input.isDirty && !causes.isEmpty {
            causes.append(RiskScore.Cause(
                title: "Unsaved changes",
                detail: "edit is in the current diff; risk is imminent",
                weight: dirtyBoost
            ))
        }

        return finalize(causes: causes, emptyHeadline: "No scoped rules or issues apply to this file.")
    }

    // MARK: - Repo aggregation

    /// Rolls per-file verdicts plus repo-wide lint into one repo verdict. The
    /// repo is only as safe as its worst file, raised further by repo-wide
    /// errors (a missing AGENTS.md is a whole-repo problem, not a file one).
    public static func aggregate(
        files: [FileScore],
        repoIssues: [LintIssue] = []
    ) -> RiskScore {
        let worst = files.max { $0.score.score < $1.score.score }
        var raw = worst?.score.score ?? 0

        var causes: [RiskScore.Cause] = []
        // Top offending files first.
        for file in files.sorted(by: { $0.score.score > $1.score.score })
        where file.score.level > .safe {
            causes.append(RiskScore.Cause(
                title: file.path,
                detail: file.score.headline,
                weight: file.score.score
            ))
        }

        for issue in repoIssues {
            let weight = issue.severity == .error ? lintErrorWeight : lintWarningWeight
            raw += weight
            causes.append(RiskScore.Cause(
                title: "Repo \(issue.severity.rawValue): \(issue.code)",
                detail: issue.message,
                weight: weight
            ))
        }

        let clamped = min(raw, 100)
        let level = level(for: clamped)
        let watching = files.filter { $0.score.level == .watch }.count
        let escalating = files.filter { $0.score.level == .escalating }.count
        let blocked = files.filter { $0.score.level == .blocked }.count

        let headline: String
        if level == .safe {
            headline = files.isEmpty
                ? "No scoped files assessed."
                : "\(files.count) file(s) assessed, none at risk."
        } else {
            var parts: [String] = []
            if blocked > 0 { parts.append("\(blocked) blocked") }
            if escalating > 0 { parts.append("\(escalating) escalating") }
            if watching > 0 { parts.append("\(watching) to watch") }
            let summary = parts.isEmpty ? "issues detected" : parts.joined(separator: ", ")
            headline = "\(level.label): \(summary)."
        }

        return RiskScore(
            level: level,
            score: clamped,
            headline: headline,
            action: action(for: level, causes: causes),
            causes: rankedCauses(causes)
        )
    }

    // MARK: - Whole-repo convenience

    /// Loads rules, lint, and conflicts for `root`, scores every rule-matched
    /// source file, and returns the repo verdict alongside the per-file scores.
    /// `changedFiles` are repo-relative paths currently in the diff.
    ///
    /// Deterministic and self-contained: the CLI's future `kujto risk` command
    /// and the Studio app can both call this and get identical numbers.
    public static func assess(
        root: URL,
        changedFiles: Set<String> = []
    ) throws -> RepoAssessment {
        let index = try RuleIndex.load(root: root)
        let allIssues = (try? MemoryLinter.lint(root: root)) ?? []
        let conflicts = ConflictLens.detect(in: index)

        // Lint issues split into per-file and repo-wide (empty or root-level file).
        let repoWideCodes: Set<String> = ["missing_agents_file", "missing_memory_index"]
        let repoIssues = allIssues.filter { repoWideCodes.contains($0.code) }
        var lintByFile: [String: [LintIssue]] = [:]
        for issue in allIssues where !repoWideCodes.contains(issue.code) {
            lintByFile[issue.file, default: []].append(issue)
        }

        // Map each rule path to the conflicts that involve it, so a source file
        // inherits the conflicts of the rules that govern it.
        var conflictsByRulePath: [String: [Conflict]] = [:]
        for conflict in conflicts {
            conflictsByRulePath[conflict.first.path, default: []].append(conflict)
            conflictsByRulePath[conflict.second.path, default: []].append(conflict)
        }

        var fileScores: [FileScore] = []
        for path in sourceFiles(under: root) {
            let matches = index.resolve(file: path)
            let fileLint = lintByFile[path] ?? []
            if matches.isEmpty && fileLint.isEmpty { continue }

            let ruleConflicts = matches.flatMap { conflictsByRulePath[$0.rule.path] ?? [] }
            // The related-tests walk is only needed when a risk rule is present.
            let needsTestCheck = matches.contains { !$0.rule.risk.isEmpty }
            let testCount = needsTestCheck ? RelatedTests.testsFor(file: path, in: root).count : 0

            let input = FileInput(
                path: path,
                matches: matches,
                lint: fileLint,
                conflicts: ruleConflicts,
                relatedTestCount: testCount,
                isDirty: changedFiles.contains(path)
            )
            fileScores.append(FileScore(path: path, score: score(input)))
        }

        let verdict = aggregate(files: fileScores, repoIssues: repoIssues)
        return RepoAssessment(
            verdict: verdict,
            files: fileScores.sorted { $0.score.score > $1.score.score },
            lintErrorCount: allIssues.filter { $0.severity == .error }.count,
            lintWarningCount: allIssues.filter { $0.severity == .warning }.count,
            conflictCount: conflicts.count
        )
    }

    // MARK: - Shared helpers

    private static func finalize(causes: [RiskScore.Cause], emptyHeadline: String) -> RiskScore {
        let ranked = rankedCauses(causes)
        let raw = min(ranked.reduce(0) { $0 + $1.weight }, 100)
        let level = level(for: raw)

        let headline: String
        if let top = ranked.first, level > .safe {
            headline = "\(top.title): \(top.detail)."
        } else {
            headline = emptyHeadline
        }

        return RiskScore(
            level: level,
            score: raw,
            headline: headline,
            action: action(for: level, causes: ranked),
            causes: ranked
        )
    }

    private static func rankedCauses(_ causes: [RiskScore.Cause]) -> [RiskScore.Cause] {
        causes.sorted { $0.weight != $1.weight ? $0.weight > $1.weight : $0.title < $1.title }
    }

    static func level(for score: Int) -> RiskScore.Level {
        switch score {
        case ..<watchThreshold: return .safe
        case ..<escalatingThreshold: return .watch
        case ..<blockedThreshold: return .escalating
        default: return .blocked
        }
    }

    private static func action(for level: RiskScore.Level, causes: [RiskScore.Cause]) -> RiskAction {
        guard level > .safe else { return .proceed }
        if level == .blocked { return .addOverrideReason }
        if causes.contains(where: { $0.title == "Conflict" }) { return .resolveConflicts }
        if causes.contains(where: { $0.title == "No related tests" }) { return .runRelatedTests }
        return .reviewContext
    }

    /// Repo-relative `.swift` source paths, skipping build artifacts and the
    /// memory tree itself (rules are inputs, not files under governance).
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
        return out.sorted()
    }
}
