import Foundation

/// The time dimension for Kujto's risk model. A verdict alone answers "how
/// risky is this repo now"; the ledger keeps the history so the dashboard can
/// answer "and where was it, and is it getting worse."
///
/// Three record kinds, one append-only local store:
///   - `RiskSnapshot`  a repo verdict at a point in time (one per assessment)
///   - `RuleOverride`  a logged human decision to proceed past a gate
///   - `ReadinessRun`  the outcome of an agent pre-flight (Phase 3 fills this)
///
/// Storage is a single JSON file the caller owns: the CLI puts it under
/// `.kujto/`, the app under Application Support. No network, ever. This is the
/// KujtoCore half of Ticket 1; the app mirrors these values into SwiftData.

/// A repo risk verdict captured at one moment, keyed by repo and time.
public struct RiskSnapshot: Codable, Sendable, Equatable {
    public let id: UUID
    /// Canonical repo root path (symlinks resolved) so lookups are stable.
    public let repoPath: String
    public let takenAt: Date
    /// Short git hash of HEAD when known, for aligning snapshots to commits.
    public let commit: String?
    public let level: RiskScore.Level
    public let score: Int
    public let headline: String
    /// How many rule-matched files were assessed.
    public let fileCount: Int
    public let watchCount: Int
    public let escalatingCount: Int
    public let blockedCount: Int
    public let lintErrorCount: Int
    public let lintWarningCount: Int
    public let conflictCount: Int

    public init(
        id: UUID = UUID(),
        repoPath: String,
        takenAt: Date = Date(),
        commit: String? = nil,
        level: RiskScore.Level,
        score: Int,
        headline: String,
        fileCount: Int,
        watchCount: Int,
        escalatingCount: Int,
        blockedCount: Int,
        lintErrorCount: Int,
        lintWarningCount: Int,
        conflictCount: Int
    ) {
        self.id = id
        self.repoPath = RuleEventLedger.normalize(repoPath)
        self.takenAt = takenAt
        self.commit = commit
        self.level = level
        self.score = score
        self.headline = headline
        self.fileCount = fileCount
        self.watchCount = watchCount
        self.escalatingCount = escalatingCount
        self.blockedCount = blockedCount
        self.lintErrorCount = lintErrorCount
        self.lintWarningCount = lintWarningCount
        self.conflictCount = conflictCount
    }
}

public extension RiskSnapshot {
    /// Builds a snapshot straight from a `RiskScorer.assess` result, deriving
    /// the per-level file counts. Keeps callers from re-deriving what the
    /// assessment already knows.
    init(_ assessment: RepoAssessment, repoPath: String, takenAt: Date = Date(), commit: String? = nil) {
        self.init(
            repoPath: repoPath,
            takenAt: takenAt,
            commit: commit,
            level: assessment.verdict.level,
            score: assessment.verdict.score,
            headline: assessment.verdict.headline,
            fileCount: assessment.files.count,
            watchCount: assessment.files.filter { $0.score.level == .watch }.count,
            escalatingCount: assessment.files.filter { $0.score.level == .escalating }.count,
            blockedCount: assessment.files.filter { $0.score.level == .blocked }.count,
            lintErrorCount: assessment.lintErrorCount,
            lintWarningCount: assessment.lintWarningCount,
            conflictCount: assessment.conflictCount
        )
    }
}

/// A human decision to proceed past a risk gate, logged locally with a reason
/// and optional expiry so Governance Rewind can later show who overrode what.
public struct RuleOverride: Codable, Sendable, Equatable {
    public let id: UUID
    public let repoPath: String
    /// Repo-relative memory rule the override applies to, if any.
    public let rulePath: String
    /// Repo-relative source file the decision was made for, if any.
    public let file: String
    public let reason: String
    public let createdAt: Date
    /// When the override stops applying. `nil` means it does not expire.
    public let expiresAt: Date?

    public init(
        id: UUID = UUID(),
        repoPath: String,
        rulePath: String = "",
        file: String = "",
        reason: String,
        createdAt: Date = Date(),
        expiresAt: Date? = nil
    ) {
        self.id = id
        self.repoPath = RuleEventLedger.normalize(repoPath)
        self.rulePath = rulePath
        self.file = file
        self.reason = reason
        self.createdAt = createdAt
        self.expiresAt = expiresAt
    }

    /// True when the override still applies at `date`.
    public func isActive(at date: Date = Date()) -> Bool {
        guard let expiresAt else { return true }
        return date < expiresAt
    }
}

/// The result of an agent pre-flight for one file. Minimal in Phase 0; the
/// Agent Sandbox (Phase 3) populates the richer fields.
public struct ReadinessRun: Codable, Sendable, Equatable {
    public let id: UUID
    public let repoPath: String
    public let file: String
    public let ranAt: Date
    public let ready: Bool
    /// Human-readable gaps that kept the agent from being ready.
    public let missingContext: [String]
    /// The risk score of the file at the time of the run.
    public let score: Int

    public init(
        id: UUID = UUID(),
        repoPath: String,
        file: String,
        ranAt: Date = Date(),
        ready: Bool,
        missingContext: [String] = [],
        score: Int
    ) {
        self.id = id
        self.repoPath = RuleEventLedger.normalize(repoPath)
        self.file = file
        self.ranAt = ranAt
        self.ready = ready
        self.missingContext = missingContext
        self.score = score
    }
}

/// Append-only, JSON-file-backed store for risk snapshots, overrides, and
/// readiness runs. Thread-safe via an internal lock. Reads are defensive
/// (a missing file reads as empty); a corrupt file surfaces on write so the
/// caller never silently clobbers existing history.
public final class RuleEventLedger {
    /// On-disk shape. Versioned so the format can evolve.
    struct Store: Codable {
        var version: Int = 1
        var snapshots: [RiskSnapshot] = []
        var overrides: [RuleOverride] = []
        var readinessRuns: [ReadinessRun] = []
    }

    public let fileURL: URL
    /// Cap on retained snapshots per repo; the oldest are pruned on write.
    private let maxSnapshotsPerRepo: Int
    private let lock = NSLock()

    public init(fileURL: URL, maxSnapshotsPerRepo: Int = 200) {
        self.fileURL = fileURL
        self.maxSnapshotsPerRepo = maxSnapshotsPerRepo
    }

    // MARK: - Recording

    public func record(_ snapshot: RiskSnapshot) throws {
        try mutate { store in
            store.snapshots.append(snapshot)
            store.snapshots = pruneSnapshots(store.snapshots)
        }
    }

    public func record(_ override: RuleOverride) throws {
        try mutate { $0.overrides.append(override) }
    }

    public func record(_ run: ReadinessRun) throws {
        try mutate { $0.readinessRuns.append(run) }
    }

    // MARK: - Queries

    /// Snapshots for a repo, newest first, optionally capped to `limit`.
    public func snapshots(forRepo repoPath: String, limit: Int? = nil) -> [RiskSnapshot] {
        let key = Self.normalize(repoPath)
        let store = (try? load()) ?? Store()
        let sorted = store.snapshots
            .filter { $0.repoPath == key }
            .sorted { $0.takenAt > $1.takenAt }
        if let limit { return Array(sorted.prefix(limit)) }
        return sorted
    }

    /// The most recent snapshot for a repo, if any.
    public func latestSnapshot(forRepo repoPath: String) -> RiskSnapshot? {
        snapshots(forRepo: repoPath, limit: 1).first
    }

    /// The snapshot before the most recent one, so the dashboard can show
    /// "current vs previous" risk without any model calls.
    public func previousSnapshot(forRepo repoPath: String) -> RiskSnapshot? {
        let recent = snapshots(forRepo: repoPath, limit: 2)
        return recent.count >= 2 ? recent[1] : nil
    }

    public func overrides(forRepo repoPath: String) -> [RuleOverride] {
        let key = Self.normalize(repoPath)
        let store = (try? load()) ?? Store()
        return store.overrides
            .filter { $0.repoPath == key }
            .sorted { $0.createdAt > $1.createdAt }
    }

    public func activeOverrides(forRepo repoPath: String, at date: Date = Date()) -> [RuleOverride] {
        overrides(forRepo: repoPath).filter { $0.isActive(at: date) }
    }

    public func readinessRuns(forRepo repoPath: String) -> [ReadinessRun] {
        let key = Self.normalize(repoPath)
        let store = (try? load()) ?? Store()
        return store.readinessRuns
            .filter { $0.repoPath == key }
            .sorted { $0.ranAt > $1.ranAt }
    }

    // MARK: - Persistence

    private func mutate(_ change: (inout Store) -> Void) throws {
        lock.lock()
        defer { lock.unlock() }
        var store = try load()
        change(&store)
        try save(store)
    }

    /// Reads the store. A missing file is an empty store; a present but
    /// unreadable file throws so a write does not overwrite real history.
    private func load() throws -> Store {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return Store() }
        let data = try Data(contentsOf: fileURL)
        if data.isEmpty { return Store() }
        return try Self.decoder.decode(Store.self, from: data)
    }

    private func save(_ store: Store) throws {
        let dir = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let data = try Self.encoder.encode(store)
        try data.write(to: fileURL, options: .atomic)
    }

    private func pruneSnapshots(_ snapshots: [RiskSnapshot]) -> [RiskSnapshot] {
        var byRepo: [String: [RiskSnapshot]] = [:]
        for snapshot in snapshots {
            byRepo[snapshot.repoPath, default: []].append(snapshot)
        }
        var kept: [RiskSnapshot] = []
        for (_, group) in byRepo {
            let trimmed = group
                .sorted { $0.takenAt > $1.takenAt }
                .prefix(maxSnapshotsPerRepo)
            kept.append(contentsOf: trimmed)
        }
        return kept.sorted { $0.takenAt < $1.takenAt }
    }

    // MARK: - Helpers

    /// Canonical key for a repo path: symlinks resolved, trailing slash removed.
    /// Keeps `~/git/x`, `~/git/x/`, and a firmlinked variant on one key. Public
    /// so the app's SwiftData store keys snapshots the same way the CLI does.
    public static func normalize(_ path: String) -> String {
        let resolved = URL(fileURLWithPath: path).resolvingSymlinksInPath().path
        if resolved.count > 1 && resolved.hasSuffix("/") {
            return String(resolved.dropLast())
        }
        return resolved
    }

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return e
    }()

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()
}
