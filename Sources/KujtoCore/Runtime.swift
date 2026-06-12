import Foundation

/// One record per `kujto run` invocation. Persisted to
/// `.kujto/runtime/apps.json` so `kujto apps` / `kujto logs` / `kujto stop`
/// can reattach across processes.
public struct LaunchedApp: Codable, Sendable {
    public var id: String
    public var bundleId: String
    public var processName: String
    public var simulatorUdid: String
    public var appPath: String
    public var launchedAt: String
    public var logStreamPid: Int?

    public init(
        id: String,
        bundleId: String,
        processName: String,
        simulatorUdid: String,
        appPath: String,
        launchedAt: String,
        logStreamPid: Int? = nil
    ) {
        self.id = id
        self.bundleId = bundleId
        self.processName = processName
        self.simulatorUdid = simulatorUdid
        self.appPath = appPath
        self.launchedAt = launchedAt
        self.logStreamPid = logStreamPid
    }
}

public final class RuntimeStore {
    public let root: URL

    public init(root: URL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)) {
        self.root = root
    }

    private var directory: URL {
        root.appendingPathComponent(".kujto").appendingPathComponent("runtime")
    }

    private var file: URL {
        directory.appendingPathComponent("apps.json")
    }

    public func list() throws -> [LaunchedApp] {
        guard FileManager.default.fileExists(atPath: file.path) else { return [] }
        let data = try Data(contentsOf: file)
        return (try? JSONDecoder().decode([LaunchedApp].self, from: data)) ?? []
    }

    public func save(_ apps: [LaunchedApp]) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(apps)
        try data.write(to: file, options: .atomic)
    }

    public func append(_ app: LaunchedApp) throws {
        var apps = try list()
        apps.append(app)
        try save(apps)
    }

    public func remove(id: String) throws -> LaunchedApp? {
        var apps = try list()
        guard let idx = apps.firstIndex(where: { $0.id == id }) else { return nil }
        let removed = apps.remove(at: idx)
        try save(apps)
        return removed
    }

    public func find(id: String) throws -> LaunchedApp? {
        try list().first { $0.id == id }
    }
}
