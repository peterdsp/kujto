import Foundation

/// Reproducible per-run directory under `.kujto/artifacts/runs/<run_id>/`.
/// Every command can stamp its events.ndjson, logs, screenshots, and result
/// bundles here, so failures are inspectable after the process exits.
public struct ArtifactStore {
    public let runId: String
    public let root: URL

    public init(root: URL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath), runId: String? = nil) throws {
        let id = runId ?? ArtifactStore.makeRunId()
        self.runId = id
        self.root = root
            .appendingPathComponent(".kujto")
            .appendingPathComponent("artifacts")
            .appendingPathComponent("runs")
            .appendingPathComponent(id)
        try FileManager.default.createDirectory(at: self.root, withIntermediateDirectories: true)
    }

    public var eventsLog: URL { root.appendingPathComponent("events.ndjson") }
    public var buildLog: URL { root.appendingPathComponent("build.log") }
    public var screenshotsDir: URL { root.appendingPathComponent("screenshots") }
    public var uiTreesDir: URL { root.appendingPathComponent("ui-trees") }
    public var appLogs: URL { root.appendingPathComponent("app-logs.ndjson") }
    public var resultBundle: URL { root.appendingPathComponent("result.xcresult") }

    private static func makeRunId() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd_HHmmss"
        f.timeZone = TimeZone(identifier: "UTC")
        return "run_" + f.string(from: Date())
    }
}
