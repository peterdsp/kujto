import Foundation
import AppKit

/// Installs the Kujto VS Code / Cursor extension into a user-granted
/// extensions folder, entirely inside the App Sandbox. No `Process`, no
/// unzipping, no external app launch:
///
///   - Kujto Studio ships the pre-extracted extension tree in
///     `Contents/Resources/EditorExtensionBundle/kujto-vscode/`.
///   - On first install we ask the user for `~/.vscode/extensions` (or the
///     Cursor equivalent) via NSOpenPanel and keep the bookmark.
///   - Every subsequent install copies the bundled tree into
///     `<grant>/peterdsp.kujto-vscode-<version>/` under that bookmark.
///
/// Because the vsix is pre-extracted at build time (see
/// `scripts/rebuild-editor-bundle.sh`) we never need a zip library at
/// runtime and the sandbox rules stay simple.
enum EditorExtensionInstaller {
    /// Marketplace publisher.name shared between VS Code and Cursor.
    static let extensionID = "peterdsp.kujto-vscode"

    enum InstallError: LocalizedError {
        case bundleMissing
        case bookmarkFailed
        case grantDenied
        case copyFailed(underlying: Error)

        var errorDescription: String? {
            switch self {
            case .bundleMissing:
                return "Kujto Studio did not ship the editor extension bundle."
            case .bookmarkFailed:
                return "Could not open the granted extensions folder."
            case .grantDenied:
                return "No extensions folder chosen."
            case .copyFailed(let error):
                return "Could not write into the extensions folder: \(error.localizedDescription)"
            }
        }
    }

    struct InstallResult {
        let installedFolder: URL
    }

    /// Runs the full install for `editor`. If we do not yet have a bookmark
    /// for that editor's extensions folder, prompts the user with an
    /// NSOpenPanel pre-focused on the conventional path. Then copies the
    /// bundled tree into `<extensions>/<extensionID>-<version>/`.
    @MainActor
    static func install(for editor: SharedConfig.Editor) throws -> InstallResult {
        guard let source = bundledExtensionURL() else {
            throw InstallError.bundleMissing
        }
        let extensionsFolder = try resolveOrPromptExtensionsFolder(for: editor)
        defer { extensionsFolder.stopAccessingSecurityScopedResource() }

        let version = extensionVersion(at: source) ?? "0.0.0"
        let targetName = "\(extensionID)-\(version)"
        let target = extensionsFolder.appendingPathComponent(targetName, isDirectory: true)

        let fm = FileManager.default
        do {
            if fm.fileExists(atPath: target.path) {
                try fm.removeItem(at: target)
            }
            try fm.copyItem(at: source, to: target)
        } catch {
            throw InstallError.copyFailed(underlying: error)
        }
        return InstallResult(installedFolder: target)
    }

    /// True if the extension folder for `editor` is present under the saved
    /// grant. Used by the wire step to switch a row's state from
    /// `.missing` -> `.ok` once the install lands.
    @MainActor
    static func isInstalled(for editor: SharedConfig.Editor) -> Bool {
        guard let folder = SharedConfig.resolveExtensionsFolder(for: editor) else { return false }
        defer { folder.stopAccessingSecurityScopedResource() }
        let contents = (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []
        return contents.contains { $0.hasPrefix(extensionID) }
    }

    // MARK: - Internals

    private static func bundledExtensionURL() -> URL? {
        Bundle.main.resourceURL?
            .appendingPathComponent("EditorExtensionBundle")
            .appendingPathComponent("kujto-vscode")
    }

    private static func extensionVersion(at bundle: URL) -> String? {
        let packageJSON = bundle.appendingPathComponent("package.json")
        guard let data = try? Data(contentsOf: packageJSON),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let version = json["version"] as? String else { return nil }
        return version
    }

    @MainActor
    private static func resolveOrPromptExtensionsFolder(for editor: SharedConfig.Editor) throws -> URL {
        if let existing = SharedConfig.resolveExtensionsFolder(for: editor) {
            return existing
        }
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.title = "Grant Kujto access to your \(editor == .vscode ? "VS Code" : "Cursor") extensions folder"
        panel.message = "Pick the extensions folder (usually ~/\(editor == .vscode ? ".vscode" : ".cursor")/extensions). Kujto only writes its own extension into it."
        panel.prompt = "Grant"
        // Nudge the panel toward the real user home. In a sandbox
        // `NSHomeDirectory()` is the container; Powerbox rewrites the URL
        // to the real path so the user starts in a useful place.
        let realHome = URL(fileURLWithPath: NSString("~").expandingTildeInPath)
        panel.directoryURL = realHome.appendingPathComponent(
            editor == .vscode ? ".vscode/extensions" : ".cursor/extensions"
        )
        guard panel.runModal() == .OK, let url = panel.url else {
            throw InstallError.grantDenied
        }
        SharedConfig.saveExtensionsFolder(url, for: editor)
        guard let scoped = SharedConfig.resolveExtensionsFolder(for: editor) else {
            throw InstallError.bookmarkFailed
        }
        return scoped
    }
}
