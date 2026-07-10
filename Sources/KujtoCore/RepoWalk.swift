import Foundation

/// Shared rules for walking a repository fast. Kujto's scanners (lint, risk,
/// related tests, proposals) all enumerate the file tree; without pruning they
/// descend into `node_modules`, `.build`, and other vendored or generated trees
/// that can dwarf the real source and make every scan crawl. Centralizing the
/// skip set keeps every walker consistent and quick.
public enum RepoWalk {
    /// Directories never worth walking into: VCS internals, build output, and
    /// vendored dependencies.
    public static let heavyDirectories: Set<String> = [
        ".git", ".build", "DerivedData", "node_modules", "Pods",
        ".swiftpm", "Carthage", ".venv", "vendor", ".next", "dist"
    ]

    /// True when `url` names a directory whose descendants should be skipped.
    /// Match is by last path component, so it prunes the tree at the boundary.
    public static func isHeavyDirectory(_ url: URL) -> Bool {
        heavyDirectories.contains(url.lastPathComponent)
    }
}
