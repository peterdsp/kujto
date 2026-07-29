import Foundation

/// Joins raw session usage to accounts by time, using the switch log.
///
/// This is the whole adapter problem in one type. The assistant records what
/// was spent; it has no idea an account switcher exists, so nothing in a
/// transcript says which account paid. The switch log says which account was
/// active at each moment. Attribution is the join, and it is deliberately
/// conservative: usage that predates the first recorded switch is reported as
/// unattributed rather than assigned to a guess.
public struct UsageAttributor: Sendable {
    private let pricing: ModelPricing

    public init(pricing: ModelPricing = .builtIn) {
        self.pricing = pricing
    }

    /// The result of attributing a batch of usage.
    public struct Result: Equatable, Sendable {
        /// Snapshots per account, ready for the UI.
        public var snapshots: [UsageSnapshot]
        /// Records that fell before the first switch, so the UI can say how
        /// much is unaccounted for instead of quietly dropping it.
        public var unattributedRecords: Int
        public var unattributedTokens: Int

        public init(snapshots: [UsageSnapshot], unattributedRecords: Int = 0,
                    unattributedTokens: Int = 0) {
            self.snapshots = snapshots
            self.unattributedRecords = unattributedRecords
            self.unattributedTokens = unattributedTokens
        }
    }

    /// Attributes `usage` to accounts using `log`.
    public func attribute(_ usage: [SessionUsage], with log: SwitchLog,
                          window: String = "all") -> Result {
        var records: [UsageTracker.Record] = []
        var unattributedRecords = 0
        var unattributedTokens = 0

        for entry in usage {
            guard let profileID = log.account(at: entry.timestamp) else {
                unattributedRecords += 1
                unattributedTokens += entry.inputTokens + entry.outputTokens
                continue
            }
            records.append(UsageTracker.Record(
                profileID: profileID,
                inputTokens: entry.inputTokens + entry.cacheReadTokens + entry.cacheWriteTokens,
                outputTokens: entry.outputTokens,
                costUSD: pricing.cost(of: entry),
                sessionID: entry.sessionID.isEmpty ? nil : entry.sessionID,
                model: entry.model))
        }

        return Result(snapshots: UsageTracker().snapshots(from: records, window: window),
                      unattributedRecords: unattributedRecords,
                      unattributedTokens: unattributedTokens)
    }

    /// Reads transcripts and attributes them in one call. `transcriptRoot` is
    /// where the assistant keeps its session files.
    public func attribute(transcriptRoot: URL, log: SwitchLog, since: Date? = nil,
                          window: String = "all",
                          reader: SessionUsageReader = SessionUsageReader()) -> Result {
        attribute(reader.scan(root: transcriptRoot, since: since), with: log, window: window)
    }
}

extension AccountPaths {
    /// Where the assistant keeps session transcripts. Overridable for the same
    /// reason the other paths are: it belongs to another tool, so it has to be
    /// pointable at a fixture rather than assumed.
    public static func transcriptRoot(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> URL {
        if let override = environment["KUJTO_TRANSCRIPTS"], !override.isEmpty {
            return URL(fileURLWithPath: override)
        }
        return FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/projects")
    }
}
