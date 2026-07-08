import Foundation

/// A repo discovered by walking a parent directory. Kujto Studio shows these
/// in the first-run wizard so the user picks from a list instead of navigating
/// a file panel.
public struct RepoEntry: Sendable, Hashable {
    public let url: URL
    public let name: String
    /// Modification date of the working tree root, when the filesystem
    /// reports one. Used to sort most-recently-touched first.
    public let modified: Date?

    public init(url: URL, name: String, modified: Date?) {
        self.url = url
        self.name = name
        self.modified = modified
    }
}

/// Discovers git repos under a chosen parent directory. Pure filesystem,
/// no network. The caller is responsible for holding the security-scope on
/// `parent` for the duration of the scan.
public enum RepoScanner {
    /// Directory names we never descend into. Keeps the walk fast on folders
    /// like `~/Developer` that also hold huge build caches.
    private static let ignored: Set<String> = [
        "node_modules", ".build", "DerivedData", "Pods",
        ".venv", "venv", "__pycache__", ".gradle",
        "build", "target", ".next", ".nuxt",
        ".cache", ".idea", ".vscode-server"
    ]

    /// Walks `parent` up to `maxDepth` levels deep and returns every folder
    /// that contains a `.git` entry. A folder counts as a repo whether `.git`
    /// is a directory (normal clone) or a file (worktree, submodule).
    ///
    /// Once a repo is found we do NOT recurse into it; nested repos still
    /// get discovered because they sit at the same level or shallower.
    public static func scan(parent: URL, maxDepth: Int = 3) -> [RepoEntry] {
        let fm = FileManager.default
        var results: [RepoEntry] = []
        var queue: [(URL, Int)] = [(parent, 0)]

        while let (url, depth) = queue.popLast() {
            if isRepo(url, fm: fm) {
                results.append(entry(for: url))
                continue
            }
            if depth >= maxDepth { continue }

            let contents = (try? fm.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )) ?? []

            for child in contents {
                let isDir = (try? child.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                guard isDir else { continue }
                if ignored.contains(child.lastPathComponent) { continue }
                queue.append((child, depth + 1))
            }
        }

        return results.sorted { lhs, rhs in
            switch (lhs.modified, rhs.modified) {
            case let (l?, r?) where l != r: return l > r
            default: return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
        }
    }

    private static func isRepo(_ url: URL, fm: FileManager) -> Bool {
        fm.fileExists(atPath: url.appendingPathComponent(".git").path)
    }

    private static func entry(for url: URL) -> RepoEntry {
        let modified = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?
            .contentModificationDate
        return RepoEntry(url: url, name: url.lastPathComponent, modified: modified)
    }
}
