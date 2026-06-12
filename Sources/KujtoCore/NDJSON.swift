import Foundation

/// Minimal JSON value sum that we know how to encode deterministically.
/// We keep this in-house instead of leaking `Any` through public APIs.
public enum NDJSONValue: Sendable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case null
    case array([NDJSONValue])
    case object([String: NDJSONValue])
}

/// One event = one JSON object per line. Field order is preserved (sorted)
/// so test fixtures stay deterministic.
public struct NDJSONEvent: Sendable {
    public var fields: [String: NDJSONValue]

    public init(fields: [String: NDJSONValue] = [:]) {
        self.fields = fields
    }

    public init(type: String, _ extra: [String: NDJSONValue] = [:]) {
        var f: [String: NDJSONValue] = ["type": .string(type)]
        for (k, v) in extra { f[k] = v }
        self.fields = f
    }
}

public struct NDJSONEncoder {
    public init() {}

    public func encode(_ event: NDJSONEvent) -> String {
        encodeObject(event.fields)
    }

    private func encodeValue(_ v: NDJSONValue) -> String {
        switch v {
        case .string(let s): return encodeString(s)
        case .int(let n): return String(n)
        case .double(let d): return String(d)
        case .bool(let b): return b ? "true" : "false"
        case .null: return "null"
        case .array(let a): return "[" + a.map(encodeValue).joined(separator: ",") + "]"
        case .object(let o): return encodeObject(o)
        }
    }

    private func encodeObject(_ o: [String: NDJSONValue]) -> String {
        let keys = o.keys.sorted()
        let parts = keys.map { key -> String in
            "\(encodeString(key)):\(encodeValue(o[key]!))"
        }
        return "{" + parts.joined(separator: ",") + "}"
    }

    private func encodeString(_ s: String) -> String {
        var out = "\""
        for c in s.unicodeScalars {
            switch c {
            case "\"": out += "\\\""
            case "\\": out += "\\\\"
            case "\n": out += "\\n"
            case "\r": out += "\\r"
            case "\t": out += "\\t"
            default:
                if c.value < 0x20 {
                    out += String(format: "\\u%04x", c.value)
                } else {
                    out += String(c)
                }
            }
        }
        out += "\""
        return out
    }
}

/// Emits events to either NDJSON (one line per event, machine-readable)
/// or human prose with colour.
public final class EventEmitter {
    public enum Mode: Sendable { case ndjson, human }

    public let mode: Mode
    private let encoder = NDJSONEncoder()
    private let lock = NSLock()

    public init(mode: Mode) {
        self.mode = mode
    }

    public func emit(_ event: NDJSONEvent) {
        lock.lock()
        defer { lock.unlock() }
        switch mode {
        case .ndjson:
            print(encoder.encode(event))
            fflush(stdout)
        case .human:
            printHuman(event)
        }
    }

    public func emit(type: String, _ extra: [String: NDJSONValue] = [:]) {
        emit(NDJSONEvent(type: type, extra))
    }

    public func emitError(_ error: KujtoError) {
        emit(error.ndjson())
    }

    private func printHuman(_ event: NDJSONEvent) {
        guard case .string(let type) = event.fields["type"] ?? .null else {
            print(encoder.encode(event))
            return
        }
        switch type {
        case "build_issue":
            let severity = stringValue(event, "severity") ?? "info"
            let file = stringValue(event, "file") ?? "?"
            let line = intValue(event, "line").map { ":\($0)" } ?? ""
            let col = intValue(event, "column").map { ":\($0)" } ?? ""
            let msg = stringValue(event, "message") ?? ""
            let marker = severity == "error" ? "✗" : "!"
            print("\(marker) \(severity): \(file)\(line)\(col): \(msg)")
        case "app_log":
            let level = stringValue(event, "level") ?? "info"
            let msg = stringValue(event, "message") ?? ""
            print("[\(level)] \(msg)")
        case "operation_started":
            let op = stringValue(event, "operation") ?? "?"
            print("▶ \(op)")
        case "operation_finished":
            let op = stringValue(event, "operation") ?? "?"
            let ok = boolValue(event, "success") ?? false
            let dur = intValue(event, "duration_ms") ?? 0
            print(ok ? "✓ \(op) (\(dur)ms)" : "✗ \(op) failed (\(dur)ms)")
        case "error":
            let code = stringValue(event, "code") ?? "?"
            let msg = stringValue(event, "message") ?? ""
            FileHandle.standardError.write("kujto: [\(code)] \(msg)\n".data(using: .utf8) ?? Data())
            if let recovery = stringValue(event, "recovery") {
                FileHandle.standardError.write("  -> \(recovery)\n".data(using: .utf8) ?? Data())
            }
        default:
            print(encoder.encode(event))
        }
    }

    private func stringValue(_ e: NDJSONEvent, _ key: String) -> String? {
        if case .string(let s) = e.fields[key] ?? .null { return s }
        return nil
    }

    private func intValue(_ e: NDJSONEvent, _ key: String) -> Int? {
        if case .int(let n) = e.fields[key] ?? .null { return n }
        return nil
    }

    private func boolValue(_ e: NDJSONEvent, _ key: String) -> Bool? {
        if case .bool(let b) = e.fields[key] ?? .null { return b }
        return nil
    }
}
