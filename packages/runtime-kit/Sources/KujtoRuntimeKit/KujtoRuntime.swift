import Foundation
import Network

/// Optional debug SDK for iOS / macOS apps that want to give Kujto Studio
/// a structured window into their runtime state.
///
/// The kit hosts a tiny HTTP listener on `127.0.0.1` (default port 7378) via
/// Network.framework. Providers you register produce `[String: Any]`
/// payloads on request. Kujto's host-side helper opens
/// `http://127.0.0.1:7378/state` to read.
///
/// - Debug only. In Release builds every entry point is a no-op - the
///   kit will not accept `register` calls when `#if DEBUG` is not set.
/// - Local only. The listener refuses any non-loopback client.
/// - Redacted. A built-in deny-list drops keys that look like `token`,
///   `password`, `key`, `secret`, `pii`, etc. Case-insensitive.
public final class KujtoRuntime: @unchecked Sendable {
    public static let shared = KujtoRuntime()

    public struct Configuration: Sendable {
        public let port: NWEndpoint.Port
        public let redactionKeywords: [String]

        public init(port: UInt16 = 7378, redactionKeywords: [String] = defaultRedaction) {
            self.port = NWEndpoint.Port(rawValue: port) ?? .init(rawValue: 7378)!
            self.redactionKeywords = redactionKeywords
        }

        public static let defaultRedaction = [
            "token", "password", "secret", "apikey", "api_key", "authorization",
            "bearer", "session", "cookie", "pii", "ssn", "cardnumber"
        ]
    }

    public typealias Provider = @Sendable () -> [String: Any]

    private var providers: [String: Provider] = [:]
    private var listener: NWListener?
    private var configuration = Configuration()
    private let queue = DispatchQueue(label: "dev.peterdsp.kujto.runtime.kit")

    private init() {}

    /// Registers a provider under `key`. Called from the host app in DEBUG
    /// only. Returns silently in Release.
    public func register(_ key: String, provider: @escaping Provider) {
        #if DEBUG
        queue.sync { providers[key] = provider }
        #endif
    }

    /// Starts the loopback listener. Idempotent - safe to call more than
    /// once. Returns silently in Release.
    public func start(_ configuration: Configuration = Configuration()) {
        #if DEBUG
        queue.sync {
            self.configuration = configuration
            guard listener == nil else { return }
            do {
                let params = NWParameters.tcp
                params.acceptLocalOnly = true
                let l = try NWListener(using: params, on: configuration.port)
                l.newConnectionHandler = { [weak self] c in self?.handle(c) }
                l.start(queue: queue)
                listener = l
            } catch {
                // Silent failure - host apps should not crash if the port is
                // busy. Kujto's host side will just report the endpoint down.
            }
        }
        #endif
    }

    public func stop() {
        #if DEBUG
        queue.sync {
            listener?.cancel()
            listener = nil
        }
        #endif
    }

    // MARK: - HTTP handling

    private func handle(_ connection: NWConnection) {
        connection.start(queue: queue)
        connection.receive(minimumIncompleteLength: 1, maximumLength: 4096) { [weak self] data, _, _, _ in
            guard let self, let data else { return }
            let response = self.respond(to: data)
            connection.send(content: response, completion: .contentProcessed { _ in
                connection.cancel()
            })
        }
    }

    private func respond(to request: Data) -> Data {
        let text = String(data: request, encoding: .utf8) ?? ""
        let firstLine = text.split(separator: "\r\n").first.map(String.init) ?? ""
        let parts = firstLine.split(separator: " ")
        let method = parts.first.map(String.init) ?? ""
        let path = parts.dropFirst().first.map(String.init) ?? "/"

        guard method == "GET" else { return httpResponse(status: 405, body: "method not allowed") }

        switch path {
        case "/state":
            let payload = snapshot()
            let json = (try? JSONSerialization.data(withJSONObject: payload, options: .prettyPrinted)) ?? Data()
            return httpResponse(status: 200, body: nil, jsonBody: json)
        case "/keys":
            let json = (try? JSONSerialization.data(withJSONObject: Array(providers.keys).sorted())) ?? Data()
            return httpResponse(status: 200, body: nil, jsonBody: json)
        default:
            return httpResponse(status: 404, body: "not found")
        }
    }

    private func snapshot() -> [String: Any] {
        var out: [String: Any] = [:]
        for (key, provider) in providers {
            out[key] = redact(provider())
        }
        return out
    }

    /// Test-only redaction entry point. Uses the shared default keyword
    /// list so tests exercise the exact same behaviour as production.
    static func debugRedact(_ value: [String: Any]) -> [String: Any] {
        (KujtoRuntime.shared.redact(value) as? [String: Any]) ?? [:]
    }

    /// Recursively drops keys that match the redaction keyword list.
    /// Values that are themselves dictionaries are traversed.
    private func redact(_ value: Any) -> Any {
        if let dict = value as? [String: Any] {
            var scrubbed: [String: Any] = [:]
            for (k, v) in dict {
                let lower = k.lowercased()
                if configuration.redactionKeywords.contains(where: { lower.contains($0) }) {
                    scrubbed[k] = "<redacted>"
                } else {
                    scrubbed[k] = redact(v)
                }
            }
            return scrubbed
        }
        if let arr = value as? [Any] {
            return arr.map(redact)
        }
        return value
    }

    private func httpResponse(status: Int, body: String? = nil, jsonBody: Data? = nil) -> Data {
        let bodyData: Data
        let contentType: String
        if let jsonBody {
            bodyData = jsonBody
            contentType = "application/json"
        } else {
            bodyData = (body ?? "").data(using: .utf8) ?? Data()
            contentType = "text/plain"
        }
        let statusText: String
        switch status {
        case 200: statusText = "OK"
        case 404: statusText = "Not Found"
        case 405: statusText = "Method Not Allowed"
        default:  statusText = "OK"
        }
        var headers = "HTTP/1.1 \(status) \(statusText)\r\n"
        headers += "Content-Type: \(contentType)\r\n"
        headers += "Content-Length: \(bodyData.count)\r\n"
        headers += "Connection: close\r\n"
        headers += "\r\n"
        var out = Data(headers.utf8)
        out.append(bodyData)
        return out
    }
}
