import Foundation

/// Detects which Kujto surfaces are present on this machine and, where the
/// sandbox does not allow finishing the install for the user, points them at
/// the next step.
///
/// Everything here has to work inside the App Sandbox: no `Process.run`, no
/// walks under the user home outside our container. The heuristics below
/// only touch world-readable system paths (`/opt/homebrew`, `/usr/local`,
/// `/Applications`) or the app's own bundle.
enum InstallStatus {
    struct Component: Identifiable, Hashable {
        var id: String { key }
        let key: String
        let name: String
        /// What the user gets when this surface is installed. One line.
        let purpose: String
        /// What functionality the user gives up if they skip it. One line.
        let skippedCost: String
        let detail: String?
        let state: State

        enum State { case ok, missing, unknown }
    }

    @MainActor
    static func snapshot() -> [Component] {
        [
            cliStatus(),
            xcodeExtensionStatus(),
            editorStatus(key: "vscode", displayName: "VS Code",
                         appPath: vscodeAppPath, editor: .vscode),
            editorStatus(key: "cursor", displayName: "Cursor",
                         appPath: cursorAppPath, editor: .cursor)
        ]
    }

    // MARK: - CLI

    /// World-readable install locations we can safely check from a sandboxed
    /// app. Everything under `~/.local/bin` is off-limits without a bookmark.
    static let cliCandidates = [
        "/opt/homebrew/bin/kujto",
        "/usr/local/bin/kujto",
        "/opt/local/bin/kujto"
    ]

    static let cliInstallCommand =
        "curl -fsSL https://raw.githubusercontent.com/peterdsp/kujto/main/bin/install.sh | bash"

    private static func cliStatus() -> Component {
        let fm = FileManager.default
        let purpose = "Runs kujto lint / rules / wire in your terminal, scripts, and CI."
        let skippedCost = "Studio still works. You lose CI checks and shell integration."
        if let hit = cliCandidates.first(where: { fm.fileExists(atPath: $0) }) {
            return Component(key: "cli", name: "kujto CLI",
                             purpose: purpose, skippedCost: skippedCost,
                             detail: hit, state: .ok)
        }
        return Component(key: "cli", name: "kujto CLI",
                         purpose: purpose, skippedCost: skippedCost,
                         detail: "not installed", state: .missing)
    }

    // MARK: - Xcode extension

    /// The `.appex` ships inside Kujto Studio itself, so the only question is
    /// whether the user has enabled it in System Settings > Extensions. We
    /// cannot query that from a sandbox, so we always ask them to enable.
    private static func xcodeExtensionStatus() -> Component {
        let bundled = Bundle.main.builtInPlugInsURL
            .flatMap { try? FileManager.default.contentsOfDirectory(at: $0, includingPropertiesForKeys: nil) }
            .map { entries in entries.contains { $0.pathExtension == "appex" } }
            ?? false
        let purpose = "Adds 'Show Kujto Rules' to Xcode's Editor menu for the open file."
        let skippedCost = "Studio's sidebar shows the same rules. You just switch apps to see them."
        return Component(
            key: "xcode",
            name: "Xcode extension",
            purpose: purpose,
            skippedCost: skippedCost,
            detail: bundled ? "enable in System Settings > Extensions" : "not bundled",
            state: bundled ? .missing : .unknown
        )
    }

    // MARK: - Editor extensions

    static let vscodeAppPath = "/Applications/Visual Studio Code.app"
    static let cursorAppPath = "/Applications/Cursor.app"
    /// Marketplace id shared between VS Code and Cursor (they both accept
    /// `vscode:extension/...` / `cursor:extension/...`).
    static let editorExtensionID = "peterdsp.kujto-vscode"

    @MainActor
    private static func editorStatus(
        key: String,
        displayName: String,
        appPath: String,
        editor: SharedConfig.Editor
    ) -> Component {
        let purpose = "Adds a 'Kujto: Show Rules' command palette entry inside \(displayName)."
        let skippedCost = "Studio shows the same rules. You lose the in-editor shortcut."
        let editorPresent = FileManager.default.fileExists(atPath: appPath)
        if editorPresent {
            let installed = EditorExtensionInstaller.isInstalled(for: editor)
            return Component(
                key: key,
                name: "\(displayName) extension",
                purpose: purpose,
                skippedCost: skippedCost,
                detail: installed ? "installed" : "install with one click",
                state: installed ? .ok : .missing
            )
        }
        return Component(
            key: key,
            name: "\(displayName) extension",
            purpose: purpose,
            skippedCost: "\(displayName) isn't installed on this Mac — nothing to add here.",
            detail: "\(displayName) not installed",
            state: .unknown
        )
    }
}
