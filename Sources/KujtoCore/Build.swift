import Foundation

/// One compile diagnostic produced by xcodebuild, parsed out of its noisy
/// log stream into a structured event.
public struct BuildIssue: Sendable {
    public let severity: String   // "error" | "warning" | "note"
    public let file: String?
    public let line: Int?
    public let column: Int?
    public let message: String

    public func event() -> NDJSONEvent {
        var f: [String: NDJSONValue] = [
            "type": .string("build_issue"),
            "severity": .string(severity),
            "message": .string(message)
        ]
        if let file = file { f["file"] = .string(file) }
        if let line = line { f["line"] = .int(line) }
        if let column = column { f["column"] = .int(column) }
        return NDJSONEvent(fields: f)
    }
}

public final class BuildIssueParser {
    /// Matches clang/swift-style diagnostics like:
    /// `/path/File.swift:42:18: error: cannot find 'user' in scope`
    private static let regex: NSRegularExpression = {
        let pattern = #"^(\/.+?):(\d+):(?:(\d+):)?\s+(error|warning|note):\s+(.+)$"#
        return try! NSRegularExpression(pattern: pattern, options: [])
    }()

    public init() {}

    public func parse(_ line: String) -> BuildIssue? {
        let range = NSRange(line.startIndex..<line.endIndex, in: line)
        guard let match = Self.regex.firstMatch(in: line, options: [], range: range) else {
            return nil
        }
        func group(_ i: Int) -> String? {
            let r = match.range(at: i)
            guard r.location != NSNotFound, let range = Range(r, in: line) else { return nil }
            return String(line[range])
        }
        let file = group(1)
        let line_ = group(2).flatMap(Int.init)
        let column = group(3).flatMap(Int.init)
        let severity = group(4) ?? "error"
        let message = group(5) ?? ""
        return BuildIssue(
            severity: severity,
            file: file,
            line: line_,
            column: column,
            message: message
        )
    }
}

public struct BuildResult: Sendable {
    public let success: Bool
    public let durationMs: Int
    public let issues: [BuildIssue]
    public let exitCode: Int32
}

public final class BuildRunner {
    private let runner: ProcessRunner
    private let parser = BuildIssueParser()
    private let emitter: EventEmitter

    public init(runner: ProcessRunner = ProcessRunner(), emitter: EventEmitter) {
        self.runner = runner
        self.emitter = emitter
    }

    /// Composes the `xcodebuild` invocation from the merged config and
    /// streams every line through the diagnostic parser so we can emit
    /// `build_issue` events as they occur.
    public func build(config: KujtoConfig, simulatorUdid: String? = nil, timeoutMs: Int? = nil) throws -> BuildResult {
        var args: [String] = []

        if let workspace = config.workspace {
            args.append(contentsOf: ["-workspace", workspace])
        } else if let project = config.project {
            args.append(contentsOf: ["-project", project])
        }

        guard let scheme = config.scheme else {
            throw KujtoError(
                code: .schemeNotFound,
                message: LMsg(
                    sq: "Asnje skeme e konfiguruar. Ekzekuto `kujto config set --scheme NAME`",
                    en: "No scheme configured. Run `kujto config set --scheme NAME`"
                )
            )
        }
        args.append(contentsOf: ["-scheme", scheme])

        let configuration = config.configuration ?? "Debug"
        args.append(contentsOf: ["-configuration", configuration])

        if let udid = simulatorUdid {
            args.append(contentsOf: ["-destination", "platform=iOS Simulator,id=\(udid)"])
        } else if let name = config.simulatorName {
            args.append(contentsOf: ["-destination", "platform=iOS Simulator,name=\(name)"])
        }

        let derived = config.derivedDataPath ?? ".kujto/DerivedData"
        args.append(contentsOf: ["-derivedDataPath", derived])

        if let extraArgs = config.xcodebuild?.args {
            args.append(contentsOf: extraArgs)
        }
        args.append("build")

        emitter.emit(type: "operation_started", [
            "operation": .string("build"),
            "scheme": .string(scheme),
            "configuration": .string(configuration)
        ])

        var issues: [BuildIssue] = []
        let started = Date()

        let env = config.xcodebuild?.env
        let result = try runner.run(
            "xcodebuild",
            arguments: args,
            environment: env,
            timeoutMs: timeoutMs,
            onStdoutLine: { [weak self] line in
                if let issue = self?.parser.parse(line) {
                    issues.append(issue)
                    self?.emitter.emit(issue.event())
                }
            },
            onStderrLine: { [weak self] line in
                if let issue = self?.parser.parse(line) {
                    issues.append(issue)
                    self?.emitter.emit(issue.event())
                }
            }
        )

        let duration = Int(Date().timeIntervalSince(started) * 1000)
        let success = result.exitCode == 0

        emitter.emit(type: "operation_finished", [
            "operation": .string("build"),
            "success": .bool(success),
            "duration_ms": .int(duration)
        ])

        if !success {
            emitter.emitError(KujtoError(
                code: .buildFailed,
                message: LMsg(
                    sq: "Ndertimi deshtoi me \(issues.filter { $0.severity == "error" }.count) gabime",
                    en: "Build failed with \(issues.filter { $0.severity == "error" }.count) errors"
                )
            ))
        }

        return BuildResult(
            success: success,
            durationMs: duration,
            issues: issues,
            exitCode: result.exitCode
        )
    }
}
