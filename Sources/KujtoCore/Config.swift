import Foundation

/// On-disk shape of `.kujto/config.json` and `.kujto/config.local.json`.
/// Local overrides committed-safe defaults; both layers merge field-by-field.
public struct KujtoConfig: Codable, Sendable {
    public var workspace: String?
    public var project: String?
    public var scheme: String?
    public var configuration: String?
    public var platform: String?
    public var simulatorName: String?
    public var simulatorUdid: String?
    public var derivedDataPath: String?
    public var lang: String?
    public var uiTestScheme: String?
    public var xcodebuild: XcodebuildSettings?

    public struct XcodebuildSettings: Codable, Sendable {
        public var args: [String]?
        public var env: [String: String]?
    }

    public init(
        workspace: String? = nil,
        project: String? = nil,
        scheme: String? = nil,
        configuration: String? = nil,
        platform: String? = nil,
        simulatorName: String? = nil,
        simulatorUdid: String? = nil,
        derivedDataPath: String? = nil,
        lang: String? = nil,
        uiTestScheme: String? = nil,
        xcodebuild: XcodebuildSettings? = nil
    ) {
        self.workspace = workspace
        self.project = project
        self.scheme = scheme
        self.configuration = configuration
        self.platform = platform
        self.simulatorName = simulatorName
        self.simulatorUdid = simulatorUdid
        self.derivedDataPath = derivedDataPath
        self.lang = lang
        self.uiTestScheme = uiTestScheme
        self.xcodebuild = xcodebuild
    }

    /// Right-hand wins for any non-nil field. Used to merge local overrides
    /// on top of shared defaults.
    public func merging(_ other: KujtoConfig) -> KujtoConfig {
        KujtoConfig(
            workspace: other.workspace ?? workspace,
            project: other.project ?? project,
            scheme: other.scheme ?? scheme,
            configuration: other.configuration ?? configuration,
            platform: other.platform ?? platform,
            simulatorName: other.simulatorName ?? simulatorName,
            simulatorUdid: other.simulatorUdid ?? simulatorUdid,
            derivedDataPath: other.derivedDataPath ?? derivedDataPath,
            lang: other.lang ?? lang,
            uiTestScheme: other.uiTestScheme ?? uiTestScheme,
            xcodebuild: other.xcodebuild ?? xcodebuild
        )
    }
}

public enum ConfigStore {
    public static let directoryName = ".kujto"
    public static let sharedName = "config.json"
    public static let localName = "config.local.json"

    public static func load(at root: URL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)) throws -> KujtoConfig {
        let dir = root.appendingPathComponent(directoryName)
        let shared = try loadOne(dir.appendingPathComponent(sharedName)) ?? KujtoConfig()
        let local = try loadOne(dir.appendingPathComponent(localName)) ?? KujtoConfig()
        return shared.merging(local)
    }

    public static func save(_ config: KujtoConfig, at root: URL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath), local: Bool = false) throws {
        let dir = root.appendingPathComponent(directoryName)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let file = dir.appendingPathComponent(local ? localName : sharedName)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(config)
        try data.write(to: file, options: .atomic)
    }

    private static func loadOne(_ url: URL) throws -> KujtoConfig? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(KujtoConfig.self, from: data)
    }
}
