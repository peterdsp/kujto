import Foundation

/// Bridges the container app and the Source Editor extension through a shared
/// App Group. The app lets the user pick a repo root; the extension reads it.
///
/// The extension is sandboxed, so the root is stored as a security-scoped
/// bookmark. A plain path is kept as a dev fallback (works when the
/// extension's sandbox is disabled during development).
enum SharedConfig {
    static let appGroup = "group.dev.peterdsp.kujto"
    private static let bookmarkKey = "ruleRootBookmark"
    private static let pathKey = "ruleRootPath"

    static func saveRoot(_ url: URL) {
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

    /// Resolves the saved repo root, starting security-scoped access when a
    /// bookmark is present. The caller must call
    /// `stopAccessingSecurityScopedResource()` when done.
    static func resolveRoot() -> URL? {
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
