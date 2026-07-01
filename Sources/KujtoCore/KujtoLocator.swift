import Foundation

/// Finds Kujto's own installation root (the directory that contains
/// `AGENTS.md` and `memory/`). Used by the Studio app when the user wires
/// their project repo; the CLI already knows its root via `KujtoRoot.locate`.
///
/// Search order:
///   1. `KUJTO_ROOT` environment variable
///   2. `~/kujto`                            (default install.sh path)
///   3. `~/.local/share/kujto`               (XDG fallback)
///   4. `~/git/personal/kujto`               (author dogfood path)
///   5. Bundle resources at `Bundle.main.resourcePath/kujto`
public enum KujtoLocator {
    public static func locate() -> URL? {
        for candidate in candidates() {
            if isValid(candidate) { return candidate }
        }
        return nil
    }

    /// True when the given URL contains an AGENTS.md and a memory directory,
    /// meaning it looks like a Kujto checkout we could wire from.
    public static func isValid(_ url: URL) -> Bool {
        let fm = FileManager.default
        let agents = url.appendingPathComponent("AGENTS.md").path
        let memory = url.appendingPathComponent("memory").path
        var isDir: ObjCBool = false
        return fm.fileExists(atPath: agents) && fm.fileExists(atPath: memory, isDirectory: &isDir) && isDir.boolValue
    }

    private static func candidates() -> [URL] {
        var out: [URL] = []
        let home = FileManager.default.homeDirectoryForCurrentUser
        if let envRoot = ProcessInfo.processInfo.environment["KUJTO_ROOT"], !envRoot.isEmpty {
            out.append(URL(fileURLWithPath: envRoot))
        }
        out.append(home.appendingPathComponent("kujto"))
        out.append(home.appendingPathComponent(".local/share/kujto"))
        out.append(home.appendingPathComponent("git/personal/kujto"))
        if let bundleRes = Bundle.main.resourcePath {
            out.append(URL(fileURLWithPath: bundleRes).appendingPathComponent("kujto"))
        }
        return out
    }
}
