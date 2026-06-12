import Foundation

/// The wire protocol between the Kujto CLI and an in-process XCTest runner.
/// The CLI writes one command JSON file per request to a shared session
/// directory; the runner watches the directory, executes against
/// `XCUIApplication`, and writes a result JSON file with the same sequence
/// number. File-based on purpose: trivial to reason about, survives process
/// crashes, easy to inspect after the fact.

public enum UIAction: String, Codable, Sendable {
    case find
    case tap
    case doubleTap = "double_tap"
    case type
    case erase
    case scroll
    case swipe
    case wait
    case assertVisible = "assert_visible"
    case assertHidden = "assert_hidden"
    case assertText = "assert_text"
    case openURL = "open_url"
    case screen
}

public struct UISelector: Codable, Sendable {
    public var label: String?
    public var identifier: String?
    public var role: String?      // "button" | "textField" | ... (XCUIElement.ElementType raw)
    public var text: String?
    public var index: Int?

    public init(
        label: String? = nil,
        identifier: String? = nil,
        role: String? = nil,
        text: String? = nil,
        index: Int? = nil
    ) {
        self.label = label
        self.identifier = identifier
        self.role = role
        self.text = text
        self.index = index
    }
}

public struct UICommand: Codable, Sendable {
    public var seq: Int
    public var action: UIAction
    public var selector: UISelector?
    public var text: String?           // for type
    public var value: String?          // for assertText
    public var url: String?            // for openURL
    public var direction: String?      // "up" | "down" | "left" | "right" for scroll/swipe
    public var seconds: Double?        // for wait
    public var timeoutMs: Int?

    public init(
        seq: Int,
        action: UIAction,
        selector: UISelector? = nil,
        text: String? = nil,
        value: String? = nil,
        url: String? = nil,
        direction: String? = nil,
        seconds: Double? = nil,
        timeoutMs: Int? = nil
    ) {
        self.seq = seq
        self.action = action
        self.selector = selector
        self.text = text
        self.value = value
        self.url = url
        self.direction = direction
        self.seconds = seconds
        self.timeoutMs = timeoutMs
    }
}

public struct UIRect: Codable, Sendable {
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double
}

public struct UIMatch: Codable, Sendable {
    public var label: String?
    public var identifier: String?
    public var elementType: String?
    public var frame: UIRect?
}

public struct UIResult: Codable, Sendable {
    public var seq: Int
    public var action: UIAction
    public var success: Bool
    public var matched: UIMatch?
    public var error: String?
    public var screenshot: String?
    public var tree: String?

    public init(
        seq: Int,
        action: UIAction,
        success: Bool,
        matched: UIMatch? = nil,
        error: String? = nil,
        screenshot: String? = nil,
        tree: String? = nil
    ) {
        self.seq = seq
        self.action = action
        self.success = success
        self.matched = matched
        self.error = error
        self.screenshot = screenshot
        self.tree = tree
    }
}

/// File-based session client. The session directory lives under
/// `.kujto/runtime/ui/<session-id>/` and contains paired `cmd-<n>.json`
/// and `result-<n>.json` files. A `session.json` at the root carries the
/// session metadata (PID of the runner, target bundle id, started_at).
public final class UISessionClient {
    public struct Session: Codable, Sendable {
        public var id: String
        public var runnerPid: Int
        public var bundleId: String?
        public var startedAt: String

        public init(id: String, runnerPid: Int, bundleId: String?, startedAt: String) {
            self.id = id
            self.runnerPid = runnerPid
            self.bundleId = bundleId
            self.startedAt = startedAt
        }
    }

    public let directory: URL
    private let encoder: JSONEncoder
    private let decoder = JSONDecoder()

    public init(directory: URL) {
        self.directory = directory
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder = e
    }

    public static func defaultRoot(cwd: URL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)) -> URL {
        cwd.appendingPathComponent(".kujto").appendingPathComponent("runtime").appendingPathComponent("ui")
    }

    public func ensureDirectory() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    public func writeSession(_ session: Session) throws {
        try ensureDirectory()
        let data = try encoder.encode(session)
        try data.write(to: directory.appendingPathComponent("session.json"), options: .atomic)
    }

    public func readSession() throws -> Session? {
        let url = directory.appendingPathComponent("session.json")
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let data = try Data(contentsOf: url)
        return try decoder.decode(Session.self, from: data)
    }

    /// Submits one command and blocks until the matching result file appears
    /// or the timeout expires. The poll interval is small enough to feel
    /// instant but doesn't burn CPU during long waits.
    public func submit(_ command: UICommand, timeoutMs: Int = 15000) throws -> UIResult {
        try ensureDirectory()
        let cmdURL = directory.appendingPathComponent("cmd-\(command.seq).json")
        let resultURL = directory.appendingPathComponent("result-\(command.seq).json")
        // Clean any stale result from a previous run with the same seq.
        try? FileManager.default.removeItem(at: resultURL)

        let data = try encoder.encode(command)
        try data.write(to: cmdURL, options: .atomic)

        let deadline = Date().addingTimeInterval(Double(timeoutMs) / 1000.0)
        while Date() < deadline {
            if FileManager.default.fileExists(atPath: resultURL.path) {
                let resultData = try Data(contentsOf: resultURL)
                return try decoder.decode(UIResult.self, from: resultData)
            }
            Thread.sleep(forTimeInterval: 0.05)
        }
        throw KujtoError(
            code: .timeout,
            message: LMsg(
                sq: "Komanda UI doli jashte kohes (\(timeoutMs)ms)",
                en: "UI command timed out (\(timeoutMs)ms)"
            )
        )
    }

    public func nextSeq() throws -> Int {
        try ensureDirectory()
        let fm = FileManager.default
        let contents = (try? fm.contentsOfDirectory(atPath: directory.path)) ?? []
        let seqs: [Int] = contents.compactMap {
            guard $0.hasPrefix("cmd-") else { return nil }
            let stripped = $0.replacingOccurrences(of: "cmd-", with: "")
                .replacingOccurrences(of: ".json", with: "")
            return Int(stripped)
        }
        return (seqs.max() ?? 0) + 1
    }
}
