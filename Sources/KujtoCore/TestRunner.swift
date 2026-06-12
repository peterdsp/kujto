import Foundation

public struct TestFailure: Sendable {
    public let target: String?
    public let testName: String
    public let file: String?
    public let line: Int?
    public let message: String

    public func event() -> NDJSONEvent {
        var f: [String: NDJSONValue] = [
            "type": .string("test_failure"),
            "name": .string(testName),
            "message": .string(message)
        ]
        if let t = target { f["target"] = .string(t) }
        if let file = file { f["file"] = .string(file) }
        if let line = line { f["line"] = .int(line) }
        return NDJSONEvent(fields: f)
    }
}

public struct TestSummary: Sendable {
    public let total: Int
    public let passed: Int
    public let failed: Int
    public let skipped: Int
    public let durationMs: Int
    public let failures: [TestFailure]
}

public final class TestRunner {
    private let runner: ProcessRunner
    private let emitter: EventEmitter

    public init(runner: ProcessRunner = ProcessRunner(), emitter: EventEmitter) {
        self.runner = runner
        self.emitter = emitter
    }

    /// Runs `xcodebuild test`, captures the result bundle, then asks
    /// `xcresulttool` for a JSON summary. Build issues during compilation
    /// of the test target are still emitted as `build_issue` events via
    /// the BuildIssueParser, so agents only need one parser pipeline.
    public func test(config: KujtoConfig, simulatorUdid: String?, resultBundle: URL, timeoutMs: Int? = nil) throws -> TestSummary {
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
                    sq: "Asnje skeme e konfiguruar.",
                    en: "No scheme configured."
                )
            )
        }
        args.append(contentsOf: ["-scheme", scheme])
        args.append(contentsOf: ["-configuration", config.configuration ?? "Debug"])
        if let udid = simulatorUdid {
            args.append(contentsOf: ["-destination", "platform=iOS Simulator,id=\(udid)"])
        } else if let name = config.simulatorName {
            args.append(contentsOf: ["-destination", "platform=iOS Simulator,name=\(name)"])
        }
        let derived = config.derivedDataPath ?? ".kujto/DerivedData"
        args.append(contentsOf: ["-derivedDataPath", derived])

        // Result bundle path must not exist or xcodebuild refuses to write it.
        try? FileManager.default.removeItem(at: resultBundle)
        try FileManager.default.createDirectory(at: resultBundle.deletingLastPathComponent(), withIntermediateDirectories: true)
        args.append(contentsOf: ["-resultBundlePath", resultBundle.path])

        if let extra = config.xcodebuild?.args { args.append(contentsOf: extra) }
        args.append("test")

        emitter.emit(type: "operation_started", [
            "operation": .string("test"),
            "scheme": .string(scheme)
        ])

        let parser = BuildIssueParser()
        let started = Date()
        let result = try runner.run(
            "xcodebuild",
            arguments: args,
            environment: config.xcodebuild?.env,
            timeoutMs: timeoutMs,
            onStdoutLine: { [weak self] line in
                if let issue = parser.parse(line) { self?.emitter.emit(issue.event()) }
            },
            onStderrLine: { [weak self] line in
                if let issue = parser.parse(line) { self?.emitter.emit(issue.event()) }
            }
        )
        let durationMs = Int(Date().timeIntervalSince(started) * 1000)

        let summary = try parseSummary(resultBundle: resultBundle, durationMs: durationMs, exitCode: result.exitCode)
        for failure in summary.failures { emitter.emit(failure.event()) }
        emitter.emit(type: "operation_finished", [
            "operation": .string("test"),
            "success": .bool(summary.failed == 0 && result.exitCode == 0),
            "duration_ms": .int(durationMs),
            "passed": .int(summary.passed),
            "failed": .int(summary.failed),
            "skipped": .int(summary.skipped),
            "total": .int(summary.total)
        ])
        return summary
    }

    private func parseSummary(resultBundle: URL, durationMs: Int, exitCode: Int32) throws -> TestSummary {
        guard FileManager.default.fileExists(atPath: resultBundle.path) else {
            return TestSummary(total: 0, passed: 0, failed: 0, skipped: 0, durationMs: durationMs, failures: [])
        }
        // Newer xcresulttool prints a deprecation warning unless we opt in,
        // but the JSON shape we read is stable enough across recent Xcodes.
        let result = try runner.run(
            "xcrun",
            arguments: [
                "xcresulttool", "get", "test-results", "summary",
                "--path", resultBundle.path,
                "--format", "json"
            ]
        )
        guard
            result.exitCode == 0,
            let data = result.stdout.data(using: .utf8),
            let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return TestSummary(total: 0, passed: 0, failed: 0, skipped: 0, durationMs: durationMs, failures: [])
        }
        let passed = obj["passedTests"] as? Int ?? 0
        let failed = obj["failedTests"] as? Int ?? 0
        let skipped = obj["skippedTests"] as? Int ?? 0
        let total = obj["totalTestCount"] as? Int ?? (passed + failed + skipped)
        var failures: [TestFailure] = []
        if let rawFailures = obj["testFailures"] as? [[String: Any]] {
            for entry in rawFailures {
                let name = (entry["testName"] as? String) ?? "?"
                let target = entry["targetName"] as? String
                let message = (entry["failureText"] as? String) ?? ""
                var file: String? = nil
                var line: Int? = nil
                if let ctx = entry["sourceCodeContext"] as? [String: Any],
                   let loc = ctx["location"] as? [String: Any] {
                    file = loc["filePath"] as? String
                    line = loc["lineNumber"] as? Int
                }
                failures.append(TestFailure(target: target, testName: name, file: file, line: line, message: message))
            }
        }
        return TestSummary(total: total, passed: passed, failed: failed, skipped: skipped, durationMs: durationMs, failures: failures)
    }
}
