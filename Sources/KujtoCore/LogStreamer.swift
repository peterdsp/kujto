import Foundation

/// One log line as emitted by `log stream --style ndjson` inside a sim. We
/// only carry the fields used by the public NDJSON event contract.
public struct AppLogLine: Sendable {
    public let level: String
    public let timestamp: String
    public let subsystem: String?
    public let category: String?
    public let process: String?
    public let message: String

    public func event() -> NDJSONEvent {
        var f: [String: NDJSONValue] = [
            "type": .string("app_log"),
            "level": .string(level),
            "timestamp": .string(timestamp),
            "message": .string(message)
        ]
        if let s = subsystem { f["subsystem"] = .string(s) }
        if let c = category { f["category"] = .string(c) }
        if let p = process { f["process"] = .string(p) }
        return NDJSONEvent(fields: f)
    }
}

public final class LogStreamer {
    private let runner: ProcessRunner
    private let emitter: EventEmitter

    public init(runner: ProcessRunner = ProcessRunner(), emitter: EventEmitter) {
        self.runner = runner
        self.emitter = emitter
    }

    /// Foreground stream until SIGINT. Returns when the child exits.
    /// Predicate priority: caller override → process name → bundle id.
    public func stream(udid: String, processName: String?, bundleId: String?, customPredicate: String?, timeoutMs: Int? = nil) throws {
        let predicate = customPredicate ?? buildPredicate(processName: processName, bundleId: bundleId)
        let args = [
            "simctl", "spawn", udid,
            "log", "stream",
            "--style", "ndjson",
            "--predicate", predicate
        ]
        emitter.emit(type: "operation_started", [
            "operation": .string("logs"),
            "udid": .string(udid),
            "predicate": .string(predicate)
        ])
        let result = try runner.run(
            "xcrun",
            arguments: args,
            timeoutMs: timeoutMs,
            onStdoutLine: { [weak self] line in
                guard let parsed = self?.parseLine(line) else { return }
                self?.emitter.emit(parsed.event())
            }
        )
        if result.exitCode != 0 {
            throw KujtoError(
                code: .logStreamFailed,
                message: LMsg(
                    sq: "Streami i log-eve doli me kod \(result.exitCode)",
                    en: "Log stream exited with code \(result.exitCode)"
                )
            )
        }
    }

    private func buildPredicate(processName: String?, bundleId: String?) -> String {
        var clauses: [String] = []
        if let p = processName, !p.isEmpty {
            clauses.append("processImagePath ENDSWITH \"/\(p)\"")
            clauses.append("process == \"\(p)\"")
        }
        if let b = bundleId, !b.isEmpty {
            clauses.append("subsystem BEGINSWITH \"\(b)\"")
        }
        if clauses.isEmpty { return "messageType >= 0" } // catch-all
        return clauses.joined(separator: " OR ")
    }

    private func parseLine(_ line: String) -> AppLogLine? {
        guard let data = line.data(using: .utf8) else { return nil }
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        let message = (obj["eventMessage"] as? String) ?? ""
        let timestamp = (obj["timestamp"] as? String) ?? ""
        let subsystem = obj["subsystem"] as? String
        let category = obj["category"] as? String
        let process = obj["processImagePath"] as? String
        let level = mapLevel(obj["messageType"] ?? obj["eventType"])
        return AppLogLine(
            level: level,
            timestamp: timestamp,
            subsystem: (subsystem?.isEmpty ?? true) ? nil : subsystem,
            category: (category?.isEmpty ?? true) ? nil : category,
            process: process.map { ($0 as NSString).lastPathComponent },
            message: message
        )
    }

    /// Apple's log subsystem reports a mix of message types depending on the
    /// `--style` flavour. Squash the lot into a small known set so agents
    /// don't have to special-case each Xcode release.
    private func mapLevel(_ raw: Any?) -> String {
        if let s = raw as? String {
            switch s.lowercased() {
            case "default", "info": return "info"
            case "debug": return "debug"
            case "error": return "error"
            case "fault": return "fault"
            case "notice": return "notice"
            default: return s.lowercased()
            }
        }
        if let n = raw as? Int {
            switch n {
            case 0: return "default"
            case 1: return "info"
            case 2: return "debug"
            case 16: return "error"
            case 17: return "fault"
            default: return "info"
            }
        }
        return "info"
    }
}
