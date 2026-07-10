import Foundation
import SwiftData
import KujtoCore

/// SwiftData storage for the risk event ledger, the app-native half of Ticket 1.
///
/// KujtoCore defines the value types (`RiskSnapshot`, `RuleOverride`,
/// `ReadinessRun`) and a JSON-file ledger for headless/CLI use. The Studio app
/// persists the same records through SwiftData so snapshots survive launches
/// and future views can query them. These `@Model` classes are thin mirrors of
/// the KujtoCore values; the store converts between the two at the boundary so
/// the rest of the app only ever sees the plain value types.

@Model
final class RiskSnapshotRecord {
    @Attribute(.unique) var id: UUID
    var repoPath: String
    var takenAt: Date
    var commit: String?
    /// `RiskScore.Level.rawValue`; kept as a String so it is `#Predicate`-safe.
    var levelRaw: String
    var score: Int
    var headline: String
    var fileCount: Int
    var watchCount: Int
    var escalatingCount: Int
    var blockedCount: Int
    var lintErrorCount: Int
    var lintWarningCount: Int
    var conflictCount: Int

    init(_ snapshot: RiskSnapshot) {
        id = snapshot.id
        repoPath = snapshot.repoPath
        takenAt = snapshot.takenAt
        commit = snapshot.commit
        levelRaw = snapshot.level.rawValue
        score = snapshot.score
        headline = snapshot.headline
        fileCount = snapshot.fileCount
        watchCount = snapshot.watchCount
        escalatingCount = snapshot.escalatingCount
        blockedCount = snapshot.blockedCount
        lintErrorCount = snapshot.lintErrorCount
        lintWarningCount = snapshot.lintWarningCount
        conflictCount = snapshot.conflictCount
    }

    var value: RiskSnapshot {
        RiskSnapshot(
            id: id,
            repoPath: repoPath,
            takenAt: takenAt,
            commit: commit,
            level: RiskScore.Level(rawValue: levelRaw) ?? .safe,
            score: score,
            headline: headline,
            fileCount: fileCount,
            watchCount: watchCount,
            escalatingCount: escalatingCount,
            blockedCount: blockedCount,
            lintErrorCount: lintErrorCount,
            lintWarningCount: lintWarningCount,
            conflictCount: conflictCount
        )
    }
}

@Model
final class RuleOverrideRecord {
    @Attribute(.unique) var id: UUID
    var repoPath: String
    var rulePath: String
    var file: String
    var reason: String
    var createdAt: Date
    var expiresAt: Date?

    init(_ override: RuleOverride) {
        id = override.id
        repoPath = override.repoPath
        rulePath = override.rulePath
        file = override.file
        reason = override.reason
        createdAt = override.createdAt
        expiresAt = override.expiresAt
    }

    var value: RuleOverride {
        RuleOverride(id: id, repoPath: repoPath, rulePath: rulePath, file: file,
                     reason: reason, createdAt: createdAt, expiresAt: expiresAt)
    }
}

@Model
final class ReadinessRunRecord {
    @Attribute(.unique) var id: UUID
    var repoPath: String
    var file: String
    var ranAt: Date
    var ready: Bool
    var missingContext: [String]
    var score: Int

    init(_ run: ReadinessRun) {
        id = run.id
        repoPath = run.repoPath
        file = run.file
        ranAt = run.ranAt
        ready = run.ready
        missingContext = run.missingContext
        score = run.score
    }

    var value: ReadinessRun {
        ReadinessRun(id: id, repoPath: repoPath, file: file, ranAt: ranAt,
                     ready: ready, missingContext: missingContext, score: score)
    }
}

/// The shared SwiftData container for risk telemetry. Falls back to in-memory
/// storage if the on-disk store cannot be opened, so risk history can never
/// block app launch.
enum RiskLedgerContainer {
    static let shared: ModelContainer = {
        let schema = Schema([
            RiskSnapshotRecord.self,
            RuleOverrideRecord.self,
            ReadinessRunRecord.self
        ])
        do {
            return try ModelContainer(for: schema)
        } catch {
            let memory = ModelConfiguration(isStoredInMemoryOnly: true)
            // If even the in-memory store fails the process is unusable; a
            // trap here is clearer than limping on with no storage.
            return try! ModelContainer(for: schema, configurations: memory)
        }
    }()
}

/// Read/write facade over the SwiftData container, speaking KujtoCore value
/// types. Mirrors `RuleEventLedger`'s query surface so views can move between
/// the two without code changes. Main-actor bound because `ModelContext` is
/// not `Sendable` and this feeds the UI.
@MainActor
final class RiskLedgerStore {
    static let shared = RiskLedgerStore()

    private let context: ModelContext
    private let maxSnapshotsPerRepo: Int

    init(container: ModelContainer = RiskLedgerContainer.shared, maxSnapshotsPerRepo: Int = 200) {
        context = ModelContext(container)
        self.maxSnapshotsPerRepo = maxSnapshotsPerRepo
    }

    // MARK: - Recording

    func record(_ snapshot: RiskSnapshot) {
        context.insert(RiskSnapshotRecord(snapshot))
        pruneSnapshots(forRepo: snapshot.repoPath)
        try? context.save()
    }

    func record(_ override: RuleOverride) {
        context.insert(RuleOverrideRecord(override))
        try? context.save()
    }

    func record(_ run: ReadinessRun) {
        context.insert(ReadinessRunRecord(run))
        try? context.save()
    }

    // MARK: - Queries

    /// Snapshots for a repo, newest first, optionally capped to `limit`.
    func snapshots(forRepo repoPath: String, limit: Int? = nil) -> [RiskSnapshot] {
        let key = RuleEventLedger.normalize(repoPath)
        var descriptor = FetchDescriptor<RiskSnapshotRecord>(
            predicate: #Predicate { $0.repoPath == key },
            sortBy: [SortDescriptor(\.takenAt, order: .reverse)]
        )
        if let limit { descriptor.fetchLimit = limit }
        let records = (try? context.fetch(descriptor)) ?? []
        return records.map { $0.value }
    }

    func latestSnapshot(forRepo repoPath: String) -> RiskSnapshot? {
        snapshots(forRepo: repoPath, limit: 1).first
    }

    /// The snapshot before the most recent, for "current vs previous" views.
    func previousSnapshot(forRepo repoPath: String) -> RiskSnapshot? {
        let recent = snapshots(forRepo: repoPath, limit: 2)
        return recent.count >= 2 ? recent[1] : nil
    }

    func activeOverrides(forRepo repoPath: String, at date: Date = Date()) -> [RuleOverride] {
        let key = RuleEventLedger.normalize(repoPath)
        let descriptor = FetchDescriptor<RuleOverrideRecord>(
            predicate: #Predicate { $0.repoPath == key },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        let records = (try? context.fetch(descriptor)) ?? []
        return records.map { $0.value }.filter { $0.isActive(at: date) }
    }

    // MARK: - Pruning

    /// Keeps only the newest `maxSnapshotsPerRepo` snapshots for one repo.
    private func pruneSnapshots(forRepo repoPath: String) {
        let key = RuleEventLedger.normalize(repoPath)
        let descriptor = FetchDescriptor<RiskSnapshotRecord>(
            predicate: #Predicate { $0.repoPath == key },
            sortBy: [SortDescriptor(\.takenAt, order: .reverse)]
        )
        guard let records = try? context.fetch(descriptor), records.count > maxSnapshotsPerRepo else { return }
        for record in records[maxSnapshotsPerRepo...] {
            context.delete(record)
        }
    }
}
