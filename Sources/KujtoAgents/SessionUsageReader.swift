import Foundation

/// One assistant turn's token usage, as read from a session transcript.
///
/// Only numbers, a model id, a timestamp, and identifiers are extracted.
/// Message content is never read into this type: usage accounting has no need
/// for what was said, and a usage file that quietly carried conversation text
/// would be a privacy problem the moment it was displayed or synced.
public struct SessionUsage: Equatable, Sendable {
    public var sessionID: String
    public var timestamp: Date
    public var model: String
    public var inputTokens: Int
    public var outputTokens: Int
    public var cacheReadTokens: Int
    public var cacheWriteTokens: Int
    /// Working directory of the session, so usage can be shown per project.
    public var project: String?

    public init(sessionID: String, timestamp: Date, model: String,
                inputTokens: Int, outputTokens: Int,
                cacheReadTokens: Int = 0, cacheWriteTokens: Int = 0,
                project: String? = nil) {
        self.sessionID = sessionID
        self.timestamp = timestamp
        self.model = model
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.cacheReadTokens = cacheReadTokens
        self.cacheWriteTokens = cacheWriteTokens
        self.project = project
    }
}

/// Reads token usage out of newline-delimited session transcripts.
///
/// The transcript format belongs to the assistant, not to Kujto, so the parser
/// is written to tolerate it changing: a line that does not look like a usage
/// record is skipped rather than failing the scan, and every field is optional
/// with a sane default. A format change degrades the numbers; it never breaks
/// the app.
public struct SessionUsageReader: Sendable {
    public init() {}

    /// Parses one transcript line. Returns nil for anything that is not an
    /// assistant turn carrying usage, which is most lines.
    public func parseLine(_ line: String) -> SessionUsage? {
        guard let data = line.data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        guard let message = root["message"] as? [String: Any],
              let usage = message["usage"] as? [String: Any] else { return nil }

        let input = Self.int(usage["input_tokens"])
        let output = Self.int(usage["output_tokens"])
        let cacheRead = Self.int(usage["cache_read_input_tokens"])
        let cacheWrite = Self.int(usage["cache_creation_input_tokens"])
        // A record with no tokens at all carries no information; skip it so it
        // does not inflate the session count.
        guard input + output + cacheRead + cacheWrite > 0 else { return nil }

        let sessionID = (root["sessionId"] as? String) ?? (root["session_id"] as? String) ?? ""
        let model = (message["model"] as? String) ?? "unknown"
        let timestamp = Self.date(root["timestamp"]) ?? Date(timeIntervalSince1970: 0)

        return SessionUsage(sessionID: sessionID, timestamp: timestamp, model: model,
                            inputTokens: input, outputTokens: output,
                            cacheReadTokens: cacheRead, cacheWriteTokens: cacheWrite,
                            project: root["cwd"] as? String)
    }

    /// Parses one transcript file.
    public func read(file url: URL) -> [SessionUsage] {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        return text.split(separator: "\n", omittingEmptySubsequences: true)
            .compactMap { parseLine(String($0)) }
    }

    /// Scans every `.jsonl` transcript under `root`, newest files first.
    ///
    /// `since` skips files untouched before that date, which is what keeps a
    /// scan cheap once a user has hundreds of sessions: the modification time
    /// is checked before a file is opened at all.
    public func scan(root: URL, since: Date? = nil, maxFiles: Int = 500) -> [SessionUsage] {
        let fm = FileManager.default
        guard let walker = fm.enumerator(at: root,
                                         includingPropertiesForKeys: [.contentModificationDateKey],
                                         options: [.skipsHiddenFiles]) else { return [] }

        var files: [(url: URL, modified: Date)] = []
        for case let url as URL in walker where url.pathExtension == "jsonl" {
            let modified = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?
                .contentModificationDate ?? Date(timeIntervalSince1970: 0)
            if let since, modified < since { continue }
            files.append((url, modified))
        }

        return files
            .sorted { $0.modified > $1.modified }
            .prefix(maxFiles)
            .flatMap { read(file: $0.url) }
    }

    // MARK: Lenient field readers

    /// Accepts an Int or a numeric String, because transcript writers differ.
    static func int(_ value: Any?) -> Int {
        if let n = value as? Int { return n }
        if let d = value as? Double { return Int(d) }
        if let s = value as? String, let n = Int(s) { return n }
        return 0
    }

    /// Accepts ISO 8601 with or without fractional seconds, and a Unix epoch.
    static func date(_ value: Any?) -> Date? {
        if let seconds = value as? Double { return Date(timeIntervalSince1970: seconds) }
        guard let text = value as? String else { return nil }
        let withFraction = ISO8601DateFormatter()
        withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = withFraction.date(from: text) { return date }
        return ISO8601DateFormatter().date(from: text)
    }
}
