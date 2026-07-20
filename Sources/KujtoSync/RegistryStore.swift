import Foundation

/// The sync format version. Bumped when the on-disk shape of the memory repo
/// changes. Stored in `.kujto/manifest.json` so a newer Kujto can migrate an
/// older repo forward, and an older Kujto refuses a newer repo rather than
/// corrupting it.
public enum SyncFormat {
    public static let current = 1
}

/// The repo's schema manifest.
public struct SyncManifest: Codable, Equatable, Sendable {
    public var syncFormatVersion: Int

    public init(syncFormatVersion: Int = SyncFormat.current) {
        self.syncFormatVersion = syncFormatVersion
    }
}

/// The outcome of reading the manifest. The store refuses to write over a repo
/// it does not understand.
public enum ManifestLoad: Equatable, Sendable {
    /// Present and at a version we can read and write.
    case ok(SyncManifest)
    /// No manifest yet: a fresh repo we can initialize.
    case missing
    /// Older than current: safe to migrate forward before writing.
    case needsMigration(from: Int)
    /// Newer than this build understands: do not write, warn the user to update.
    case tooNew(version: Int)
}

/// Reads and writes `registry.json` and `.kujto/manifest.json` at the root of
/// the synced memory repo. Serialization is stable (sorted keys, normalized
/// content) so the git history of the registry stays legible and merge-clean.
public struct RegistryStore: Sendable {
    private let repo: URL

    public init(repo: URL) {
        self.repo = repo
    }

    private var registryURL: URL { repo.appendingPathComponent("registry.json") }
    private var manifestURL: URL { repo.appendingPathComponent(".kujto/manifest.json") }

    // MARK: Manifest

    public func loadManifest() throws -> ManifestLoad {
        guard FileManager.default.fileExists(atPath: manifestURL.path) else { return .missing }
        let data = try Data(contentsOf: manifestURL)
        let manifest = try JSONDecoder().decode(SyncManifest.self, from: data)
        if manifest.syncFormatVersion > SyncFormat.current {
            return .tooNew(version: manifest.syncFormatVersion)
        }
        if manifest.syncFormatVersion < SyncFormat.current {
            return .needsMigration(from: manifest.syncFormatVersion)
        }
        return .ok(manifest)
    }

    /// Creates the manifest and an empty registry when absent. Refuses a repo
    /// written by a newer Kujto.
    @discardableResult
    public func ensureInitialized() throws -> ManifestLoad {
        let load = try loadManifest()
        switch load {
        case .tooNew:
            return load
        case .missing:
            try write(SyncManifest(), to: manifestURL)
            if !FileManager.default.fileExists(atPath: registryURL.path) {
                try saveRegistry(ProjectRegistry())
            }
            return .ok(SyncManifest())
        case .needsMigration:
            // Forward migration is a no-op today (v1 is the first version); we
            // stamp the current version so the next read is clean.
            try write(SyncManifest(), to: manifestURL)
            return .ok(SyncManifest())
        case .ok:
            return load
        }
    }

    // MARK: Registry

    /// Loads the registry, returning an empty one when the file is absent.
    public func loadRegistry() throws -> ProjectRegistry {
        guard FileManager.default.fileExists(atPath: registryURL.path) else {
            return ProjectRegistry()
        }
        let data = try Data(contentsOf: registryURL)
        return try JSONDecoder().decode(ProjectRegistry.self, from: data)
    }

    /// Saves the registry in normalized, stable form.
    public func saveRegistry(_ registry: ProjectRegistry) throws {
        try write(registry.normalized(), to: registryURL)
    }

    // MARK: Plumbing

    private func write<T: Encodable>(_ value: T, to url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(value)
        try data.write(to: url, options: .atomic)
    }
}
