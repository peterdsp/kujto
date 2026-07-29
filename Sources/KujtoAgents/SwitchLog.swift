import Foundation

/// One account activation. The log of these is what makes usage attributable:
/// a session's tokens belong to whichever account was active when it ran, and
/// nothing else records that.
public struct SwitchEvent: Codable, Equatable, Sendable {
    public var profileID: String
    /// When the account became active.
    public var at: Date

    public init(profileID: String, at: Date) {
        self.profileID = profileID
        self.at = at
    }
}

/// An append-only record of account activations, kept next to the roster.
///
/// Usage data records what was spent and when, but not by whom, because the
/// assistant has no idea an account switcher exists. Joining the two on time is
/// the only honest way to attribute spend, so the switch log is a first-class
/// file rather than a side effect.
public struct SwitchLog: Codable, Equatable, Sendable {
    public var events: [SwitchEvent]

    public init(events: [SwitchEvent] = []) {
        self.events = events
    }

    /// Adds an activation, keeping the log ordered oldest first.
    public mutating func record(_ profileID: String, at date: Date) {
        events.append(SwitchEvent(profileID: profileID, at: date))
        events.sort { $0.at < $1.at }
    }

    /// The account active at `date`, or nil when the log starts after it.
    ///
    /// Usage that predates the first recorded switch is deliberately left
    /// unattributed rather than assigned to the earliest account: guessing
    /// would silently inflate one account's numbers, and the whole point of
    /// showing usage is that the user can trust it.
    public func account(at date: Date) -> String? {
        var current: String?
        for event in events {
            if event.at <= date { current = event.profileID } else { break }
        }
        return current
    }

    /// Drops events older than `date`, keeping the one in force at that moment
    /// so attribution near the boundary stays correct.
    public mutating func prune(before date: Date) {
        guard let index = events.lastIndex(where: { $0.at <= date }) else { return }
        events = Array(events[index...])
    }
}

/// Reads and writes the switch log as `switch-log.json` under the Kujto root.
/// It lives outside the synced memory repo: it is machine-local history, and
/// syncing it would interleave two machines' switches into one timeline that
/// describes neither.
public struct SwitchLogStore: Sendable {
    private let url: URL

    public init(root: URL) {
        self.url = root.appendingPathComponent("switch-log.json")
    }

    public func load() throws -> SwitchLog {
        guard FileManager.default.fileExists(atPath: url.path) else { return SwitchLog() }
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(SwitchLog.self, from: data)
    }

    public func save(_ log: SwitchLog) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        try encoder.encode(log).write(to: url, options: .atomic)
    }

    /// Appends one activation.
    public func record(_ profileID: String, at date: Date) throws {
        var log = (try? load()) ?? SwitchLog()
        log.record(profileID, at: date)
        try save(log)
    }
}

extension SwitchLog {
    /// Dates decode as ISO 8601 to match how they are written.
    public static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
