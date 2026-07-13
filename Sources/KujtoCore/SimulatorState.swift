import Foundation

/// Pure builder for `simctl` argument arrays. Kept side-effect free so the
/// exact command line each control produces can be unit tested without a
/// running simulator. Every method returns the arguments passed to
/// `xcrun` (i.e. starting with `simctl`), matching how `SimulatorController`
/// already calls `runner.run("xcrun", arguments: [...])`.
public enum SimctlArgs {
    public static func appearance(udid: String, style: String) -> [String] {
        ["simctl", "ui", udid, "appearance", style]
    }

    public static func locationSet(udid: String, latitude: Double, longitude: Double) -> [String] {
        ["simctl", "location", udid, "set", "\(latitude),\(longitude)"]
    }

    public static func locationClear(udid: String) -> [String] {
        ["simctl", "location", udid, "clear"]
    }

    public static func locationRun(udid: String, scenario: String) -> [String] {
        ["simctl", "location", udid, "run", scenario]
    }

    public static func statusBarClear(udid: String) -> [String] {
        ["simctl", "status_bar", udid, "clear"]
    }

    /// Only the flags the caller actually set are appended, matching
    /// `simctl status_bar override` (at least one flag is required).
    public static func statusBarOverride(
        udid: String,
        time: String? = nil,
        dataNetwork: String? = nil,
        wifiBars: Int? = nil,
        cellularBars: Int? = nil,
        batteryState: String? = nil,
        batteryLevel: Int? = nil
    ) -> [String] {
        var args = ["simctl", "status_bar", udid, "override"]
        if let time = time { args += ["--time", time] }
        if let dataNetwork = dataNetwork { args += ["--dataNetwork", dataNetwork] }
        if let wifiBars = wifiBars { args += ["--wifiBars", String(wifiBars)] }
        if let cellularBars = cellularBars { args += ["--cellularBars", String(cellularBars)] }
        if let batteryState = batteryState { args += ["--batteryState", batteryState] }
        if let batteryLevel = batteryLevel { args += ["--batteryLevel", String(batteryLevel)] }
        return args
    }

    /// `bundleId` is optional because the payload may carry a
    /// `Simulator Target Bundle` key. Pass `-` as `payloadPath` for stdin.
    public static func push(udid: String, bundleId: String?, payloadPath: String) -> [String] {
        var args = ["simctl", "push", udid]
        if let bundleId = bundleId, !bundleId.isEmpty { args.append(bundleId) }
        args.append(payloadPath)
        return args
    }

    public static func privacy(udid: String, action: String, service: String, bundleId: String?) -> [String] {
        var args = ["simctl", "privacy", udid, action, service]
        if let bundleId = bundleId, !bundleId.isEmpty { args.append(bundleId) }
        return args
    }

    public static func getAppContainer(udid: String, bundleId: String, kind: String?) -> [String] {
        var args = ["simctl", "get_app_container", udid, bundleId]
        if let kind = kind, !kind.isEmpty { args.append(kind) }
        return args
    }

    public static func pasteboardCopy(udid: String) -> [String] {
        ["simctl", "pbcopy", udid]
    }

    public static func pasteboardPaste(udid: String) -> [String] {
        ["simctl", "pbpaste", udid]
    }

    public static func create(name: String, deviceType: String, runtime: String?) -> [String] {
        var args = ["simctl", "create", name, deviceType]
        if let runtime = runtime, !runtime.isEmpty { args.append(runtime) }
        return args
    }

    public static func delete(target: String) -> [String] {
        ["simctl", "delete", target]
    }
}

/// Device-state controls layered on top of `SimulatorController`. These wrap
/// `simctl` subcommands that were missing from Kujto's toolchain surface:
/// appearance, simulated location, status bar, push, privacy, pasteboard,
/// app container path, and simulator create/delete.
extension SimulatorController {
    /// A convenience for controls that don't already return a `Result`.
    private func runSimctl(_ args: [String], failure: KujtoError.Code = .process, what: String) throws -> String {
        let result = try runner.run("xcrun", arguments: args)
        guard result.exitCode == 0 else {
            throw KujtoError(
                code: failure,
                message: LMsg(
                    sq: "\(what) deshtoi: \(result.stderr.isEmpty ? result.stdout : result.stderr)",
                    en: "\(what) failed: \(result.stderr.isEmpty ? result.stdout : result.stderr)"
                )
            )
        }
        return result.stdout
    }

    public func setAppearance(udid: String, style: String) throws {
        _ = try runSimctl(SimctlArgs.appearance(udid: udid, style: style), what: "Appearance")
    }

    public func setLocation(udid: String, latitude: Double, longitude: Double) throws {
        _ = try runSimctl(SimctlArgs.locationSet(udid: udid, latitude: latitude, longitude: longitude), what: "Location set")
    }

    public func clearLocation(udid: String) throws {
        _ = try runSimctl(SimctlArgs.locationClear(udid: udid), what: "Location clear")
    }

    public func runLocationScenario(udid: String, scenario: String) throws {
        _ = try runSimctl(SimctlArgs.locationRun(udid: udid, scenario: scenario), what: "Location scenario")
    }

    public func overrideStatusBar(_ args: [String]) throws {
        _ = try runSimctl(args, what: "Status bar override")
    }

    public func clearStatusBar(udid: String) throws {
        _ = try runSimctl(SimctlArgs.statusBarClear(udid: udid), what: "Status bar clear")
    }

    public func sendPush(udid: String, bundleId: String?, payloadPath: String) throws {
        _ = try runSimctl(SimctlArgs.push(udid: udid, bundleId: bundleId, payloadPath: payloadPath), what: "Push")
    }

    public func setPrivacy(udid: String, action: String, service: String, bundleId: String?) throws {
        _ = try runSimctl(SimctlArgs.privacy(udid: udid, action: action, service: service, bundleId: bundleId), what: "Privacy \(action)")
    }

    /// Returns the on-disk container path for an installed app.
    public func appContainer(udid: String, bundleId: String, kind: String?) throws -> String {
        let out = try runSimctl(SimctlArgs.getAppContainer(udid: udid, bundleId: bundleId, kind: kind),
                                failure: .appInstallFailed, what: "get_app_container")
        return out.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Returns the created simulator's UDID (simctl prints it on stdout).
    public func createSimulator(name: String, deviceType: String, runtime: String?) throws -> String {
        let out = try runSimctl(SimctlArgs.create(name: name, deviceType: deviceType, runtime: runtime),
                                failure: .simulatorNotFound, what: "Create simulator")
        return out.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public func deleteSimulator(target: String) throws {
        _ = try runSimctl(SimctlArgs.delete(target: target), failure: .simulatorNotFound, what: "Delete simulator")
    }

    public func pasteboardContents(udid: String) throws -> String {
        try runSimctl(SimctlArgs.pasteboardPaste(udid: udid), what: "Pasteboard paste")
    }

    /// `simctl pbcopy` reads the pasteboard text from stdin, which the shared
    /// `ProcessRunner` can't feed, so we drive `Process` directly here.
    public func copyToPasteboard(udid: String, text: String) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        process.arguments = SimctlArgs.pasteboardCopy(udid: udid)
        let stdin = Pipe()
        process.standardInput = stdin
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
        } catch {
            throw KujtoError(
                code: .process,
                message: LMsg(
                    sq: "Nuk munda te ekzekutoj pbcopy: \(error.localizedDescription)",
                    en: "Failed to execute pbcopy: \(error.localizedDescription)"
                )
            )
        }
        stdin.fileHandleForWriting.write(Data(text.utf8))
        try? stdin.fileHandleForWriting.close()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw KujtoError(
                code: .process,
                message: LMsg(sq: "Kopjimi ne pasteboard deshtoi", en: "Pasteboard copy failed")
            )
        }
    }
}
