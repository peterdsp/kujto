import Foundation
import AppKit

/// Installs the bundled `kujto` CLI into a user-granted PATH folder, entirely
/// inside the App Sandbox. Mirrors EditorExtensionInstaller: no `Process`, no
/// external launch.
///
///   - The direct build ships the `kujto` binary at `Contents/Resources/kujto`
///     (see the Release-Direct post-build step in project.yml). The App Store
///     build does not bundle it, so `bundledBinaryURL()` returns nil there and
///     the onboarding falls back to the copy-the-command path.
///   - On first install we ask the user for a bin folder on their PATH (we
///     suggest ~/.local/bin) via NSOpenPanel and keep the bookmark.
///   - Every install copies the bundled binary into `<grant>/kujto` and marks
///     it executable.
enum CLIInstaller {
    enum InstallError: LocalizedError {
        case binaryMissing
        case grantDenied
        case copyFailed(underlying: Error)

        var errorDescription: String? {
            switch self {
            case .binaryMissing:
                return "This build of Kujto Studio does not ship the kujto CLI."
            case .grantDenied:
                return "No bin folder chosen."
            case .copyFailed(let error):
                return "Could not write into the bin folder: \(error.localizedDescription)"
            }
        }
    }

    struct InstallResult {
        let installedPath: URL
        /// True when the granted folder is not on the current PATH, so the
        /// caller can tell the user to add it.
        let needsPathHint: Bool
    }

    /// The bundled CLI binary, present only when the app was built with it
    /// (direct build). nil in the App Store build.
    static func bundledBinaryURL() -> URL? {
        guard let url = Bundle.main.resourceURL?.appendingPathComponent("kujto"),
              FileManager.default.isExecutableFile(atPath: url.path) else { return nil }
        return url
    }

    /// Whether this build can perform a one-click CLI install.
    static var canInstall: Bool { bundledBinaryURL() != nil }

    /// Copies the bundled binary into a user-granted bin folder, prompting for
    /// the folder once. Returns where it landed and whether the folder needs
    /// adding to PATH.
    @MainActor
    static func install() throws -> InstallResult {
        guard let source = bundledBinaryURL() else { throw InstallError.binaryMissing }
        let binFolder = try resolveOrPromptBinFolder()
        defer { binFolder.stopAccessingSecurityScopedResource() }

        let target = binFolder.appendingPathComponent("kujto", isDirectory: false)
        let fm = FileManager.default
        do {
            if fm.fileExists(atPath: target.path) {
                try fm.removeItem(at: target)
            }
            try fm.copyItem(at: source, to: target)
            try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: target.path)
        } catch {
            throw InstallError.copyFailed(underlying: error)
        }
        return InstallResult(installedPath: target, needsPathHint: !folderIsOnPath(binFolder))
    }

    /// True when a `kujto` binary already sits in the granted bin folder.
    static func isInstalled() -> Bool {
        guard let folder = SharedConfig.resolveBinFolder() else { return false }
        defer { folder.stopAccessingSecurityScopedResource() }
        return FileManager.default.isExecutableFile(
            atPath: folder.appendingPathComponent("kujto").path
        )
    }

    // MARK: - Internals

    @MainActor
    private static func resolveOrPromptBinFolder() throws -> URL {
        if let existing = SharedConfig.resolveBinFolder() {
            return existing
        }
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.title = "Grant Kujto a folder on your PATH"
        panel.message = "Pick a bin folder on your PATH (we suggest ~/.local/bin). Kujto copies only its own CLI into it."
        panel.prompt = "Grant"
        // In a sandbox NSHomeDirectory() is the container; Powerbox rewrites
        // the URL to the real path, so start the user somewhere useful.
        let realHome = URL(fileURLWithPath: NSString("~").expandingTildeInPath)
        panel.directoryURL = realHome.appendingPathComponent(".local/bin")
        guard panel.runModal() == .OK, let url = panel.url else {
            throw InstallError.grantDenied
        }
        SharedConfig.saveBinFolder(url)
        guard let scoped = SharedConfig.resolveBinFolder() else {
            throw InstallError.grantDenied
        }
        return scoped
    }

    private static func folderIsOnPath(_ folder: URL) -> Bool {
        let path = ProcessInfo.processInfo.environment["PATH"] ?? ""
        let entries = path.split(separator: ":").map(String.init)
        let target = folder.standardizedFileURL.path
        return entries.contains { $0 == target || $0 == folder.path }
    }
}
