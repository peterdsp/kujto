import Foundation
import Network
import KujtoCore

/// Localhost HTTP server that speaks a subset of OpenAI's Chat Completions
/// API so PromptBar (or any OpenAI-compatible client) can point at Kujto
/// and query the repo's memory as if it were an LLM.
///
/// Scope of this MVP:
///   - Listens on 127.0.0.1:7377 by default.
///   - Handles POST /v1/chat/completions with a JSON body.
///   - Extracts the last user message.
///   - Answers by searching the current repo's memory (via RuleIndex) and
///     assembling a cited response. No upstream model call — the response
///     is Kujto's own knowledge.
///   - Non-streaming for now. PromptBar accepts non-streaming responses.
///
/// What is deliberately NOT here yet:
///   - SSE streaming (would double the surface for MVP).
///   - Upstream forwarding to a real LLM (Claude/OpenAI) with tool use.
///   - Auth (bearer token acceptance).
/// Those come after PromptBar is validated against this endpoint end-to-end.
@MainActor
final class PromptBarBridge: ObservableObject {
    static let shared = PromptBarBridge()

    @Published private(set) var isRunning = false
    @Published private(set) var lastError: String?

    /// The repo root the bridge answers questions about. Set by the caller
    /// whenever the user picks a new repo in the Codex.
    var repoRoot: URL?

    private let port: NWEndpoint.Port
    private var listener: NWListener?
    private let queue = DispatchQueue(label: "dev.peterdsp.kujto.promptbar")

    private init(port: UInt16 = 7377) {
        self.port = NWEndpoint.Port(rawValue: port) ?? .init(rawValue: 7377)!
    }

    // MARK: Lifecycle

    func start() {
        guard listener == nil else { return }
        do {
            let params = NWParameters.tcp
            params.acceptLocalOnly = true
            let l = try NWListener(using: params, on: port)
            l.newConnectionHandler = { [weak self] c in
                Task { @MainActor [weak self] in self?.handle(c) }
            }
            l.stateUpdateHandler = { [weak self] state in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    switch state {
                    case .ready: self.isRunning = true
                    case .failed(let error):
                        self.isRunning = false
                        self.lastError = error.localizedDescription
                    case .cancelled:
                        self.isRunning = false
                    default: break
                    }
                }
            }
            l.start(queue: queue)
            listener = l
        } catch {
            lastError = error.localizedDescription
        }
    }

    func stop() {
        listener?.cancel()
        listener = nil
        isRunning = false
    }

    // MARK: HTTP handling

    private func handle(_ connection: NWConnection) {
        connection.start(queue: queue)
        readFullRequest(from: connection) { [weak self] rawRequest in
            guard let self else { return }
            Task { @MainActor [weak self] in
                guard let self else { return }
                let response = self.route(rawRequest)
                connection.send(content: response, completion: .contentProcessed { _ in
                    connection.cancel()
                })
            }
        }
    }

    /// Reads until we've consumed both headers and the declared Content-Length
    /// body. Naive but sufficient for PromptBar's request shape (small JSON).
    /// nonisolated: runs entirely on the NWConnection's queue and touches no
    /// main-actor state, so it must not hop back to the main actor per read.
    private nonisolated func readFullRequest(from connection: NWConnection, done: @escaping @Sendable (Data) -> Void) {
        var buffer = Data()
        func loop() {
            connection.receive(minimumIncompleteLength: 1, maximumLength: 32_768) { data, _, isDone, _ in
                if let data { buffer.append(data) }
                if let bodyStart = buffer.range(of: Data("\r\n\r\n".utf8)) {
                    let headers = String(data: buffer.subdata(in: 0..<bodyStart.lowerBound), encoding: .utf8) ?? ""
                    let expected = self.contentLength(from: headers)
                    let currentBody = buffer.count - bodyStart.upperBound
                    if currentBody >= expected || isDone {
                        done(buffer); return
                    }
                }
                if isDone { done(buffer); return }
                loop()
            }
        }
        loop()
    }

    private nonisolated func contentLength(from headers: String) -> Int {
        for line in headers.split(separator: "\r\n") {
            if line.lowercased().hasPrefix("content-length:") {
                return Int(line.split(separator: ":", maxSplits: 1).last?.trimmingCharacters(in: .whitespaces) ?? "0") ?? 0
            }
        }
        return 0
    }

    private func route(_ raw: Data) -> Data {
        let text = String(data: raw, encoding: .utf8) ?? ""
        let firstLine = text.split(separator: "\r\n").first.map(String.init) ?? ""
        let parts = firstLine.split(separator: " ")
        let method = parts.first.map(String.init) ?? ""
        let path = parts.dropFirst().first.map(String.init) ?? "/"

        if method == "GET" && path == "/v1/models" {
            return http(200, json: modelsResponse())
        }
        if method == "POST" && path == "/v1/chat/completions" {
            return handleChatCompletion(raw: raw)
        }
        return http(404, text: "not found")
    }

    // MARK: Chat completion

    private func handleChatCompletion(raw: Data) -> Data {
        guard let bodyStart = raw.range(of: Data("\r\n\r\n".utf8))?.upperBound,
              let body = try? JSONSerialization.jsonObject(with: raw.subdata(in: bodyStart..<raw.count)) as? [String: Any] else {
            return http(400, text: "invalid JSON body")
        }
        let messages = (body["messages"] as? [[String: Any]]) ?? []
        let userQuestion = messages.reversed()
            .first(where: { ($0["role"] as? String) == "user" })?["content"] as? String
            ?? ""

        let answer = answerFromMemory(question: userQuestion)
        let response: [String: Any] = [
            "id": "chatcmpl-kujto-\(UUID().uuidString)",
            "object": "chat.completion",
            "created": Int(Date().timeIntervalSince1970),
            "model": "kujto-memory",
            "choices": [[
                "index": 0,
                "message": ["role": "assistant", "content": answer],
                "finish_reason": "stop"
            ]],
            "usage": ["prompt_tokens": 0, "completion_tokens": 0, "total_tokens": 0]
        ]
        return http(200, json: response)
    }

    private func modelsResponse() -> [String: Any] {
        [
            "object": "list",
            "data": [[
                "id": "kujto-memory",
                "object": "model",
                "owned_by": "kujto",
                "created": 0
            ]]
        ]
    }

    /// Turns a user question into a Kujto-memory-backed answer. Uses simple
    /// heuristics for MVP: filename-like tokens trigger a Memory Trace,
    /// everything else does a substring search over rule titles + text.
    private func answerFromMemory(question: String) -> String {
        guard let root = repoRoot else {
            return "Kujto isn't pointed at a repo yet. Open Kujto Studio and pick one."
        }
        guard let index = try? RuleIndex.load(root: root) else {
            return "Kujto could not read this repo's memory."
        }

        if let file = extractFilePath(question) {
            let matches = index.resolve(file: file)
            if matches.isEmpty {
                return "No file-scoped rules match \(file). Only base memory applies."
            }
            var lines = ["Rules for \(file):"]
            for m in matches.prefix(8) {
                let risk = m.rule.risk.isEmpty ? "" : " [risk: \(m.rule.risk.joined(separator: ", "))]"
                lines.append("- \(m.rule.title)\(risk) — \(m.rule.path) (matched \(m.glob))")
            }
            return lines.joined(separator: "\n")
        }

        // Free-text search over rule titles and paths.
        let q = question.lowercased()
        let candidates = index.rules.filter { rule in
            rule.title.lowercased().contains(q) || rule.path.lowercased().contains(q)
        }
        if candidates.isEmpty {
            return "Kujto found no matching rule for \"\(question)\". Try a file path (e.g. Sources/Home/HomeReducer.swift) or a rule title."
        }
        var lines = ["Rules matching \"\(question)\":"]
        for rule in candidates.prefix(8) {
            lines.append("- \(rule.title) — \(rule.path)")
        }
        return lines.joined(separator: "\n")
    }

    /// Best-effort extraction of a file path from a natural-language query.
    private func extractFilePath(_ text: String) -> String? {
        // Look for tokens that end with a known code extension.
        let extensions = [".swift", ".ts", ".tsx", ".js", ".py", ".rs", ".kt", ".go", ".java", ".m", ".mm"]
        for token in text.split(whereSeparator: { $0.isWhitespace || $0 == "," || $0 == ":" }) {
            let str = String(token)
            if extensions.contains(where: { str.lowercased().hasSuffix($0) }) {
                return str
            }
        }
        return nil
    }

    // MARK: - HTTP encoding

    private func http(_ status: Int, text: String) -> Data {
        writeResponse(status: status, contentType: "text/plain", body: Data(text.utf8))
    }

    private func http(_ status: Int, json object: [String: Any]) -> Data {
        let body = (try? JSONSerialization.data(withJSONObject: object)) ?? Data()
        return writeResponse(status: status, contentType: "application/json", body: body)
    }

    private func writeResponse(status: Int, contentType: String, body: Data) -> Data {
        let statusText: String
        switch status {
        case 200: statusText = "OK"
        case 400: statusText = "Bad Request"
        case 404: statusText = "Not Found"
        default:  statusText = "OK"
        }
        var header = "HTTP/1.1 \(status) \(statusText)\r\n"
        header += "Content-Type: \(contentType)\r\n"
        header += "Content-Length: \(body.count)\r\n"
        header += "Access-Control-Allow-Origin: *\r\n"
        header += "Connection: close\r\n"
        header += "\r\n"
        var out = Data(header.utf8)
        out.append(body)
        return out
    }
}
