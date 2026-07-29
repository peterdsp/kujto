import Foundation

/// What an account has spent, so the user can see where they are before they
/// run out rather than after. Token counts and cost are optional because not
/// every backend reports both.
public struct UsageSnapshot: Equatable, Sendable {
    public var profileID: String
    public var inputTokens: Int
    public var outputTokens: Int
    /// Cost in USD when the source reports it.
    public var costUSD: Double?
    /// Sessions counted toward this snapshot.
    public var sessions: Int
    /// The window these numbers cover, for example "today".
    public var window: String

    public init(profileID: String, inputTokens: Int = 0, outputTokens: Int = 0,
                costUSD: Double? = nil, sessions: Int = 0, window: String = "all") {
        self.profileID = profileID
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.costUSD = costUSD
        self.sessions = sessions
        self.window = window
    }

    public var totalTokens: Int { inputTokens + outputTokens }

    /// A one-line summary for the menu bar and the switch confirmation.
    public var summary: String {
        var parts = ["\(Self.compact(totalTokens)) tokens"]
        if let cost = costUSD {
            parts.append(String(format: "$%.2f", cost))
        }
        if sessions > 0 {
            parts.append("\(sessions) session\(sessions == 1 ? "" : "s")")
        }
        return parts.joined(separator: " · ")
    }

    /// 1234 -> "1.2k", 1234567 -> "1.2M". Keeps the glyph readable.
    static func compact(_ n: Int) -> String {
        switch n {
        case ..<1_000: return "\(n)"
        case ..<1_000_000: return String(format: "%.1fk", Double(n) / 1_000)
        default: return String(format: "%.1fM", Double(n) / 1_000_000)
        }
    }
}

/// Aggregates usage records into per-account snapshots.
///
/// The reader is injected rather than reading a fixed path, because every
/// assistant records usage somewhere different and the format is not ours to
/// depend on. Kujto's job is the arithmetic and the presentation; a vendor
/// adapter supplies the records.
public struct UsageTracker: Sendable {
    /// One usage line as an adapter reports it.
    public struct Record: Equatable, Sendable {
        public var profileID: String
        public var inputTokens: Int
        public var outputTokens: Int
        public var costUSD: Double?
        /// Session identifier, so sessions are counted rather than lines.
        public var sessionID: String?

        public init(profileID: String, inputTokens: Int, outputTokens: Int,
                    costUSD: Double? = nil, sessionID: String? = nil) {
            self.profileID = profileID
            self.inputTokens = inputTokens
            self.outputTokens = outputTokens
            self.costUSD = costUSD
            self.sessionID = sessionID
        }
    }

    public init() {}

    /// Folds records into one snapshot per account. Cost is summed only from
    /// records that report it, and stays nil when none do, so a missing cost
    /// never renders as a confident $0.00.
    public func snapshots(from records: [Record], window: String = "all") -> [UsageSnapshot] {
        var byProfile: [String: UsageSnapshot] = [:]
        var sessionsByProfile: [String: Set<String>] = [:]

        for record in records {
            var snapshot = byProfile[record.profileID]
                ?? UsageSnapshot(profileID: record.profileID, window: window)
            snapshot.inputTokens += record.inputTokens
            snapshot.outputTokens += record.outputTokens
            if let cost = record.costUSD {
                snapshot.costUSD = (snapshot.costUSD ?? 0) + cost
            }
            byProfile[record.profileID] = snapshot

            if let session = record.sessionID {
                sessionsByProfile[record.profileID, default: []].insert(session)
            }
        }

        return byProfile.map { id, snapshot in
            var copy = snapshot
            copy.sessions = sessionsByProfile[id]?.count ?? 0
            return copy
        }.sorted { $0.profileID < $1.profileID }
    }

    /// The snapshot for one account, or an empty one so the UI always has a
    /// value to render.
    public func snapshot(for profileID: String, from records: [Record],
                         window: String = "all") -> UsageSnapshot {
        snapshots(from: records.filter { $0.profileID == profileID }, window: window).first
            ?? UsageSnapshot(profileID: profileID, window: window)
    }
}
