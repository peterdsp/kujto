import Foundation
import AppKit
import KujtoCore

/// Sandbox-safe detection of the local iOS runtime tooling that the
/// eventual Simulator Trace feature will drive. Everything here is
/// read-only and only ever touches system paths that are world-readable
/// (`/Applications/Xcode.app`) or a folder the user has explicitly granted
/// via `NSOpenPanel` (`~/Library/Developer/CoreSimulator/Devices`).
///
/// Real automated control needs the Kujto helper daemon (SMAppService) -
/// coming in Phase D2. This file only reports what's installed; it never
/// launches or manipulates the simulator itself.
enum RuntimeDetector {
    struct Snapshot {
        let xcodeInstalled: Bool
        let xcodePath: String?
        /// True when the user has granted `~/Library/Developer/CoreSimulator/Devices/`.
        let simulatorGranted: Bool
        let simulators: [LocalSimulator]
    }

    static let xcodeAppPath = "/Applications/Xcode.app"

    @MainActor
    static func snapshot() -> Snapshot {
        let xcode = FileManager.default.fileExists(atPath: xcodeAppPath)
        let sims = loadSimulators()
        return Snapshot(
            xcodeInstalled: xcode,
            xcodePath: xcode ? xcodeAppPath : nil,
            simulatorGranted: sims != nil,
            simulators: sims ?? []
        )
    }

    /// Returns nil when the CoreSimulator grant is missing so the UI can
    /// distinguish "no grant yet" from "granted, no devices installed".
    @MainActor
    private static func loadSimulators() -> [LocalSimulator]? {
        guard let root = SharedConfig.resolveCoreSimulatorFolder() else { return nil }
        defer { root.stopAccessingSecurityScopedResource() }
        return SimulatorInventory.load(devicesRoot: root)
    }

    /// Prompts the user to grant access to the CoreSimulator devices folder.
    /// Pre-focuses the panel on the standard developer path so the click
    /// count is small. Returns true if a grant was saved.
    @MainActor
    @discardableResult
    static func grantCoreSimulatorAccess() -> Bool {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.title = "Grant Kujto access to CoreSimulator devices"
        panel.message = "Pick ~/Library/Developer/CoreSimulator/Devices so Kujto can list the simulators you already have. Kujto only reads; it never launches or modifies the simulator here."
        panel.prompt = "Grant"
        let realHome = URL(fileURLWithPath: NSString("~").expandingTildeInPath)
        panel.directoryURL = realHome.appendingPathComponent("Library/Developer/CoreSimulator/Devices")
        guard panel.runModal() == .OK, let url = panel.url else { return false }
        SharedConfig.saveCoreSimulatorFolder(url)
        return true
    }
}
