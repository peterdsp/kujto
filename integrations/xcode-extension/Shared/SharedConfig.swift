import Foundation

/// Bridges the container app and the Source Editor extension through a shared
/// App Group. The app lets the user pick a repo root; the extension reads it.
///
/// The extension is sandboxed, so the root is stored as a security-scoped
/// bookmark. A plain path is kept as a dev fallback (works when the
/// extension's sandbox is disabled during development).
enum SharedConfig {
    static let appGroup = "YTS4KJBX3P.dev.peterdsp.kujto"
    private static let bookmarkKey = "ruleRootBookmark"
    private static let pathKey = "ruleRootPath"
    private static let scanParentBookmarkKey = "scanParentBookmark"
    private static let scanParentPathKey = "scanParentPath"

    // Extensions-folder bookmarks per editor. Once the user grants
    // ~/.vscode/extensions (or ~/.cursor/extensions), we reuse the scope on
    // every re-install without re-prompting.
    private static let vscodeExtensionsBookmarkKey = "vscodeExtensionsBookmark"
    private static let vscodeExtensionsPathKey = "vscodeExtensionsPath"
    private static let cursorExtensionsBookmarkKey = "cursorExtensionsBookmark"
    private static let cursorExtensionsPathKey = "cursorExtensionsPath"

    // Global skills-folder bookmark for Claude Code.
    // Grants ~/.claude/skills the first time the user installs a skill globally.
    private static let claudeSkillsBookmarkKey = "claudeSkillsBookmark"
    private static let claudeSkillsPathKey = "claudeSkillsPath"

    // CoreSimulator devices grant. Points at
    // ~/Library/Developer/CoreSimulator/Devices/ once the user grants it.
    private static let coreSimulatorBookmarkKey = "coreSimulatorBookmark"
    private static let coreSimulatorPathKey = "coreSimulatorPath"

    // PATH bin-folder grant for the bundled kujto CLI. Points at the folder
    // (e.g. ~/.local/bin) the user grants the first time they install the CLI.
    private static let binFolderBookmarkKey = "binFolderBookmark"
    private static let binFolderPathKey = "binFolderPath"

    static func saveRoot(_ url: URL) {
        save(url, bookmarkKey: bookmarkKey, pathKey: pathKey)
    }

    /// Resolves the saved repo root, starting security-scoped access when a
    /// bookmark is present. The caller must call
    /// `stopAccessingSecurityScopedResource()` when done.
    static func resolveRoot() -> URL? {
        resolve(bookmarkKey: bookmarkKey, pathKey: pathKey)
    }

    /// Persists the parent folder Kujto scans for repos (e.g. `~/git`).
    /// Kept alongside `ruleRoot` so opening a specific repo from the scan
    /// list does not overwrite the scan location.
    static func saveScanParent(_ url: URL) {
        save(url, bookmarkKey: scanParentBookmarkKey, pathKey: scanParentPathKey)
    }

    /// Resolves the saved scan parent. Starts security-scoped access when a
    /// bookmark is present; caller must stop the scope when done.
    static func resolveScanParent() -> URL? {
        resolve(bookmarkKey: scanParentBookmarkKey, pathKey: scanParentPathKey)
    }

    /// Which editor a folder-grant belongs to.
    enum Editor: String {
        case vscode, cursor

        fileprivate var bookmarkKey: String {
            switch self {
            case .vscode: return vscodeExtensionsBookmarkKey
            case .cursor: return cursorExtensionsBookmarkKey
            }
        }
        fileprivate var pathKey: String {
            switch self {
            case .vscode: return vscodeExtensionsPathKey
            case .cursor: return cursorExtensionsPathKey
            }
        }
    }

    /// Persists the folder the user granted for `editor`'s extensions dir.
    static func saveExtensionsFolder(_ url: URL, for editor: Editor) {
        save(url, bookmarkKey: editor.bookmarkKey, pathKey: editor.pathKey)
    }

    /// Resolves the persisted extensions-folder grant for `editor`.
    /// Starts security-scoped access; caller must stop the scope when done.
    static func resolveExtensionsFolder(for editor: Editor) -> URL? {
        resolve(bookmarkKey: editor.bookmarkKey, pathKey: editor.pathKey)
    }

    /// Persists the ~/.claude/skills grant used for global skill installs.
    static func saveClaudeSkillsFolder(_ url: URL) {
        save(url, bookmarkKey: claudeSkillsBookmarkKey, pathKey: claudeSkillsPathKey)
    }

    /// Resolves the persisted ~/.claude/skills grant. Starts security-scoped
    /// access; caller must stop the scope when done.
    static func resolveClaudeSkillsFolder() -> URL? {
        resolve(bookmarkKey: claudeSkillsBookmarkKey, pathKey: claudeSkillsPathKey)
    }

    /// Persists the PATH bin folder the user granted for the kujto CLI.
    static func saveBinFolder(_ url: URL) {
        save(url, bookmarkKey: binFolderBookmarkKey, pathKey: binFolderPathKey)
    }

    /// Resolves the persisted bin-folder grant. Starts security-scoped access;
    /// caller must stop the scope when done.
    static func resolveBinFolder() -> URL? {
        resolve(bookmarkKey: binFolderBookmarkKey, pathKey: binFolderPathKey)
    }

    /// Persists the CoreSimulator devices folder grant.
    static func saveCoreSimulatorFolder(_ url: URL) {
        save(url, bookmarkKey: coreSimulatorBookmarkKey, pathKey: coreSimulatorPathKey)
    }

    /// Resolves the persisted CoreSimulator devices folder grant. Starts
    /// security-scoped access; caller must stop the scope when done.
    static func resolveCoreSimulatorFolder() -> URL? {
        resolve(bookmarkKey: coreSimulatorBookmarkKey, pathKey: coreSimulatorPathKey)
    }

    // MARK: - Shared bookmark helpers

    private static func save(_ url: URL, bookmarkKey: String, pathKey: String) {
        guard let defaults = UserDefaults(suiteName: appGroup) else { return }
        if let bookmark = try? url.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        ) {
            defaults.set(bookmark, forKey: bookmarkKey)
        }
        defaults.set(url.path, forKey: pathKey)
    }

    private static func resolve(bookmarkKey: String, pathKey: String) -> URL? {
        guard let defaults = UserDefaults(suiteName: appGroup) else { return nil }
        if let bookmark = defaults.data(forKey: bookmarkKey) {
            var stale = false
            if let url = try? URL(
                resolvingBookmarkData: bookmark,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &stale
            ) {
                _ = url.startAccessingSecurityScopedResource()
                return url
            }
        }
        if let path = defaults.string(forKey: pathKey) {
            return URL(fileURLWithPath: path)
        }
        return nil
    }
}
