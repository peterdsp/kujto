import Foundation

/// Phase 8 of the Repository Intelligence OS: Repo Sentiment.
///
/// A single "memory debt" heartbeat leaders can watch, derived only from real
/// signals Kujto already measures: lint issues, structural conflicts, rules
/// gone stale in git, and logged overrides. The doc's guardrail is that the
/// metric must explain its inputs and never invent a vanity number, so every
/// point traces to a named component with its count.
public struct DebtComponent: Sendable, Equatable, Codable {
    public let name: String
    public let count: Int
    public let points: Int
    public let note: String

    public init(name: String, count: Int, points: Int, note: String) {
        self.name = name
        self.count = count
        self.points = points
        self.note = note
    }
}

public struct MemoryDebt: Sendable, Equatable, Codable {
    public enum Grade: String, Sendable, Codable {
        case healthy
        case watch
        case heavy

        public var label: String {
            switch self {
            case .healthy: return "Healthy"
            case .watch: return "Watch"
            case .heavy: return "Heavy"
            }
        }
    }

    /// 0...100, higher is more debt.
    public let score: Int
    public let grade: Grade
    /// Every input that contributed, with its count and points. This is the
    /// "explains its inputs" contract.
    public let components: [DebtComponent]
    /// One-sentence leadership summary.
    public let summary: String

    public init(score: Int, grade: Grade, components: [DebtComponent], summary: String) {
        self.score = score
        self.grade = grade
        self.components = components
        self.summary = summary
    }
}

public enum MemoryDebtScanner {

    // Points per unit of each signal. Documented so the number is auditable.
    static let lintErrorPoints = 10
    static let lintWarningPoints = 3
    static let conflictPoints = 8
    static let staleRulePoints = 4
    static let overridePoints = 5

    static let watchThreshold = 20
    static let heavyThreshold = 50

    /// Computes the debt heartbeat for `root`. Reads lint, conflicts, and rule
    /// staleness from the repo; `overrideCount` comes from the caller's ledger.
    /// `now` and `staleDays` are injectable for testing.
    public static func assess(
        root: URL,
        overrideCount: Int = 0,
        staleDays: Int = 180,
        now: Date = Date(),
        runner: ProcessRunner = ProcessRunner()
    ) throws -> MemoryDebt {
        let index = try RuleIndex.load(root: root)
        let issues = (try? MemoryLinter.lint(root: root)) ?? []
        let conflicts = ConflictLens.detect(in: index)

        let lintErrors = issues.filter { $0.severity == .error }.count
        let lintWarnings = issues.filter { $0.severity == .warning }.count
        let stale = staleRuleCount(index: index, in: root, staleDays: staleDays, now: now, runner: runner)

        return score(
            lintErrors: lintErrors,
            lintWarnings: lintWarnings,
            conflicts: conflicts.count,
            staleRules: stale,
            overrides: overrideCount
        )
    }

    /// Pure scoring from counts. Kept separate so the weighting is unit-tested
    /// without touching git or the filesystem.
    public static func score(
        lintErrors: Int,
        lintWarnings: Int,
        conflicts: Int,
        staleRules: Int,
        overrides: Int
    ) -> MemoryDebt {
        var components: [DebtComponent] = []
        func add(_ name: String, _ count: Int, _ unit: Int, _ note: String) {
            guard count > 0 else { return }
            components.append(DebtComponent(name: name, count: count, points: count * unit, note: note))
        }
        add("Lint errors", lintErrors, lintErrorPoints, "missing or broken memory files")
        add("Lint warnings", lintWarnings, lintWarningPoints, "unmatched globs or broken links")
        add("Conflicts", conflicts, conflictPoints, "rules that disagree with each other")
        add("Stale rules", staleRules, staleRulePoints, "rules untouched beyond the staleness window")
        add("Overrides", overrides, overridePoints, "active risk gates a human bypassed")

        let raw = min(components.reduce(0) { $0 + $1.points }, 100)
        let grade: MemoryDebt.Grade = raw >= heavyThreshold ? .heavy : (raw >= watchThreshold ? .watch : .healthy)

        let summary: String
        if components.isEmpty {
            summary = "Memory debt is Healthy (0/100): no lint issues, conflicts, stale rules, or overrides."
        } else {
            let parts = components.map { "\($0.count) \($0.name.lowercased())" }.joined(separator: ", ")
            summary = "Memory debt is \(grade.label) (\(raw)/100): \(parts)."
        }

        return MemoryDebt(score: raw, grade: grade, components: components, summary: summary)
    }

    // MARK: - Staleness

    /// Rules whose most recent commit is older than the staleness window. A
    /// rule with no git history (new or uncommitted) is not counted as stale.
    static func staleRuleCount(
        index: RuleIndex,
        in root: URL,
        staleDays: Int,
        now: Date,
        runner: ProcessRunner
    ) -> Int {
        let cutoff = now.addingTimeInterval(-Double(staleDays) * 86_400)
        var stale = 0
        for rule in index.rules {
            let history = RuleHistoryScanner.history(forRule: rule.path, in: root, limit: 1, runner: runner)
            guard let latest = history.first, let date = parseDate(latest.date) else { continue }
            if date < cutoff { stale += 1 }
        }
        return stale
    }

    static func parseDate(_ string: String) -> Date? {
        Self.dateFormatter.date(from: string)
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
}
