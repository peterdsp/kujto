import Foundation

/// Detects what parts of Kujto Studio are actually installed on this machine.
/// Shown in the Welcome wizard's status step and in Settings so the user can
/// see which surfaces are wired up and which still need action.
///
/// Detection is best-effort and read-only. We never modify user config here.
enum InstallStatus {
    struct Component: Identifiable, Hashable {
        var id: String { key }
        let key: String
        let name: String
        let detail: String?
        let state: State

        enum State { case ok, missing, unknown }
    }

    static func snapshot() -> [Component] {
        [
            cliStatus(),
            xcodeExtensionStatus(),
            vscodeExtensionStatus(),
            cursorExtensionStatus()
        ]
    }

    private static func cliStatus() -> Component {
        // `which kujto` locates the CLI in PATH. If missing the user has not
        // run install.sh (or the tap has not shipped yet).
        if let path = runCapturing("/usr/bin/which", ["kujto"]).trimmedNonEmpty {
            return Component(key: "cli", name: "kujto CLI", detail: path, state: .ok)
        }
        return Component(key: "cli", name: "kujto CLI", detail: "not on PATH", state: .missing)
    }

    private static func xcodeExtensionStatus() -> Component {
        // pluginkit lists registered app extensions. Our bundle id is set in
        // the appex Info.plist and project.yml.
        let output = runCapturing("/usr/bin/pluginkit", ["-m", "-i", "dev.peterdsp.kujto.studio.RulesExtension"])
        if output.contains("dev.peterdsp.kujto.studio.RulesExtension") {
            return Component(key: "xcode", name: "Xcode extension", detail: "registered", state: .ok)
        }
        return Component(key: "xcode", name: "Xcode extension", detail: "not registered", state: .missing)
    }

    private static func vscodeExtensionStatus() -> Component {
        vscodeLike(commandName: "code", displayName: "VS Code", extensionsDir: ".vscode/extensions")
    }

    private static func cursorExtensionStatus() -> Component {
        vscodeLike(commandName: "cursor", displayName: "Cursor", extensionsDir: ".cursor/extensions")
    }

    private static func vscodeLike(commandName: String, displayName: String, extensionsDir: String) -> Component {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let path = home.appendingPathComponent(extensionsDir).path
        let fm = FileManager.default
        guard fm.fileExists(atPath: path) else {
            return Component(key: commandName, name: "\(displayName) extension", detail: "\(displayName) not detected", state: .unknown)
        }
        if let entries = try? fm.contentsOfDirectory(atPath: path),
           entries.contains(where: { $0.lowercased().contains("kujto") }) {
            return Component(key: commandName, name: "\(displayName) extension", detail: "installed", state: .ok)
        }
        return Component(key: commandName, name: "\(displayName) extension", detail: "not installed", state: .missing)
    }

    private static func runCapturing(_ launchPath: String, _ arguments: [String]) -> String {
        let process = Process()
        process.launchPath = launchPath
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8) ?? ""
        } catch {
            return ""
        }
    }
}

private extension String {
    var trimmedNonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
