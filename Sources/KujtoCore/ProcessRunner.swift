import Foundation

/// Thin wrapper around `Process` that streams stdout and stderr line by line,
/// optionally captures everything, and surfaces typed errors instead of raw
/// `NSError`s. Used by every command that shells out to xcodebuild, simctl,
/// devicectl, or log.
public final class ProcessRunner {
    public struct Result: Sendable {
        public let exitCode: Int32
        public let stdout: String
        public let stderr: String
        public let durationMs: Int
    }

    public typealias LineHandler = (String) -> Void

    public init() {}

    @discardableResult
    public func run(
        _ executable: String,
        arguments: [String],
        environment: [String: String]? = nil,
        cwd: URL? = nil,
        timeoutMs: Int? = nil,
        onStdoutLine: LineHandler? = nil,
        onStderrLine: LineHandler? = nil
    ) throws -> Result {
        let process = Process()
        process.executableURL = resolveExecutable(executable)
        process.arguments = arguments
        if let cwd = cwd { process.currentDirectoryURL = cwd }

        var env = ProcessInfo.processInfo.environment
        if let environment = environment {
            for (k, v) in environment { env[k] = v }
        }
        process.environment = env

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        let stdoutBuffer = LineBuffer { line in onStdoutLine?(line) }
        let stderrBuffer = LineBuffer { line in onStderrLine?(line) }

        stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if data.isEmpty { return }
            stdoutBuffer.feed(data)
        }
        stderrPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if data.isEmpty { return }
            stderrBuffer.feed(data)
        }

        let started = Date()
        do {
            try process.run()
        } catch {
            throw KujtoError(
                code: .process,
                message: LMsg(
                    sq: "Nuk munda te ekzekutoj \(executable): \(error.localizedDescription)",
                    en: "Failed to execute \(executable): \(error.localizedDescription)"
                )
            )
        }

        // Optional timeout: arm a dispatch timer that sends SIGTERM, then
        // SIGKILL after a short grace period. The "timedOut" flag survives
        // into the error path so the caller can map it to ExitCode.timeout.
        var timedOut = false
        var timer: DispatchSourceTimer?
        if let ms = timeoutMs, ms > 0 {
            timer = DispatchSource.makeTimerSource(queue: DispatchQueue.global())
            timer?.schedule(deadline: .now() + .milliseconds(ms))
            timer?.setEventHandler { [weak process] in
                guard let process = process, process.isRunning else { return }
                timedOut = true
                kill(process.processIdentifier, SIGTERM)
                DispatchQueue.global().asyncAfter(deadline: .now() + .seconds(2)) {
                    if process.isRunning { kill(process.processIdentifier, SIGKILL) }
                }
            }
            timer?.resume()
        }

        process.waitUntilExit()
        timer?.cancel()

        if timedOut {
            throw KujtoError(
                code: .timeout,
                message: LMsg(
                    sq: "\(executable) doli jashte kohes (\(timeoutMs!)ms)",
                    en: "\(executable) timed out after \(timeoutMs!)ms"
                )
            )
        }

        stdoutPipe.fileHandleForReading.readabilityHandler = nil
        stderrPipe.fileHandleForReading.readabilityHandler = nil
        stdoutBuffer.flush()
        stderrBuffer.flush()

        let durationMs = Int(Date().timeIntervalSince(started) * 1000)

        return Result(
            exitCode: process.terminationStatus,
            stdout: stdoutBuffer.captured,
            stderr: stderrBuffer.captured,
            durationMs: durationMs
        )
    }

    /// Runs a command, captures stdout as JSON, and decodes it.
    public func runJSON<T: Decodable>(
        _ executable: String,
        arguments: [String],
        type: T.Type
    ) throws -> T {
        let result = try run(executable, arguments: arguments)
        guard result.exitCode == 0 else {
            throw KujtoError(
                code: .process,
                message: LMsg(
                    sq: "\(executable) doli me kod \(result.exitCode)",
                    en: "\(executable) exited with code \(result.exitCode)"
                )
            )
        }
        guard let data = result.stdout.data(using: .utf8) else {
            throw KujtoError(
                code: .process,
                message: LMsg(
                    sq: "Dalja e \(executable) nuk eshte UTF-8",
                    en: "\(executable) output is not UTF-8"
                )
            )
        }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw KujtoError(
                code: .process,
                message: LMsg(
                    sq: "Dalja e \(executable) nuk eshte JSON i vlefshem: \(error.localizedDescription)",
                    en: "\(executable) output is not valid JSON: \(error.localizedDescription)"
                )
            )
        }
    }

    private func resolveExecutable(_ name: String) -> URL {
        if name.hasPrefix("/") { return URL(fileURLWithPath: name) }
        // Walk $PATH so we match shell behavior.
        if let path = ProcessInfo.processInfo.environment["PATH"] {
            for dir in path.split(separator: ":") {
                let url = URL(fileURLWithPath: String(dir)).appendingPathComponent(name)
                if FileManager.default.isExecutableFile(atPath: url.path) {
                    return url
                }
            }
        }
        // Common fallbacks for Apple toolchain binaries.
        let fallbacks = ["/usr/bin/\(name)", "/usr/local/bin/\(name)", "/opt/homebrew/bin/\(name)"]
        for path in fallbacks {
            if FileManager.default.isExecutableFile(atPath: path) {
                return URL(fileURLWithPath: path)
            }
        }
        return URL(fileURLWithPath: name)
    }
}

/// Splits an incoming byte stream into newline-terminated lines while keeping
/// a full transcript for callers that want the captured output.
private final class LineBuffer {
    private var pending = ""
    var captured = ""
    private let onLine: (String) -> Void
    private let lock = NSLock()

    init(onLine: @escaping (String) -> Void) {
        self.onLine = onLine
    }

    func feed(_ data: Data) {
        guard let text = String(data: data, encoding: .utf8) else { return }
        lock.lock()
        captured += text
        pending += text
        while let newline = pending.firstIndex(of: "\n") {
            let line = String(pending[..<newline])
            pending.removeSubrange(...newline)
            lock.unlock()
            onLine(line)
            lock.lock()
        }
        lock.unlock()
    }

    func flush() {
        lock.lock()
        let leftover = pending
        pending = ""
        lock.unlock()
        if !leftover.isEmpty { onLine(leftover) }
    }
}
