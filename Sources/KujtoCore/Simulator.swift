import Foundation

public struct SimulatorDevice: Codable, Sendable {
    public let name: String
    public let udid: String
    public let state: String
    public let isAvailable: Bool?
    public let deviceTypeIdentifier: String?
    public let runtime: String?
}

public final class SimulatorController {
    private let runner: ProcessRunner

    public init(runner: ProcessRunner = ProcessRunner()) {
        self.runner = runner
    }

    /// Wraps `xcrun simctl list devices available --json`.
    /// The JSON keys devices under a runtime identifier, so we flatten and
    /// stamp each device with its runtime for convenience.
    public func listDevices(platform: String? = nil) throws -> [SimulatorDevice] {
        var args = ["simctl", "list", "devices", "available", "--json"]
        if let platform = platform { args.append(platform) }
        let result = try runner.run("xcrun", arguments: args)
        guard result.exitCode == 0, let data = result.stdout.data(using: .utf8) else {
            throw KujtoError(
                code: .simulatorNotFound,
                message: LMsg(
                    sq: "Nuk munda te listoj simulatoret",
                    en: "Failed to list simulators"
                ),
                recovery: LMsg(
                    sq: "Sigurohu qe Xcode eshte instaluar dhe ekzekuto `xcrun simctl list devices`",
                    en: "Ensure Xcode is installed and run `xcrun simctl list devices`"
                )
            )
        }
        let raw = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let devices = raw?["devices"] as? [String: [[String: Any]]] ?? [:]
        var out: [SimulatorDevice] = []
        for (runtime, list) in devices {
            for entry in list {
                guard
                    let name = entry["name"] as? String,
                    let udid = entry["udid"] as? String,
                    let state = entry["state"] as? String
                else { continue }
                out.append(SimulatorDevice(
                    name: name,
                    udid: udid,
                    state: state,
                    isAvailable: entry["isAvailable"] as? Bool,
                    deviceTypeIdentifier: entry["deviceTypeIdentifier"] as? String,
                    runtime: runtime
                ))
            }
        }
        return out.sorted { $0.name < $1.name }
    }

    public func resolveUdid(name: String? = nil, udid: String? = nil) throws -> String {
        if let udid = udid, !udid.isEmpty { return udid }
        let devices = try listDevices()
        if let name = name, !name.isEmpty {
            if let match = devices.first(where: { $0.name == name }) { return match.udid }
            throw KujtoError(
                code: .simulatorNotFound,
                message: LMsg(
                    sq: "Asnje simulator iOS i emertuar '\(name)'",
                    en: "No iOS simulator named '\(name)'"
                ),
                recovery: LMsg(
                    sq: "Ekzekuto `kujto simulator list` per opsionet",
                    en: "Run `kujto simulator list` to see options"
                )
            )
        }
        if let any = devices.first(where: { $0.state == "Booted" }) { return any.udid }
        if let any = devices.first { return any.udid }
        throw KujtoError(
            code: .simulatorNotFound,
            message: LMsg(
                sq: "Asnje simulator i disponueshem",
                en: "No simulators available"
            )
        )
    }

    @discardableResult
    public func boot(udid: String) throws -> ProcessRunner.Result {
        let result = try runner.run("xcrun", arguments: ["simctl", "boot", udid])
        if result.exitCode != 0 && !result.stderr.contains("Booted") && !result.stderr.contains("current state Booted") {
            throw KujtoError(
                code: .simulatorBootFailed,
                message: LMsg(
                    sq: "Booti i simulatorit \(udid) deshtoi",
                    en: "Failed to boot simulator \(udid)"
                )
            )
        }
        return result
    }

    @discardableResult
    public func shutdown(udid: String) throws -> ProcessRunner.Result {
        try runner.run("xcrun", arguments: ["simctl", "shutdown", udid])
    }

    @discardableResult
    public func erase(udid: String) throws -> ProcessRunner.Result {
        try runner.run("xcrun", arguments: ["simctl", "erase", udid])
    }

    public func screenshot(udid: String, output: URL) throws {
        try FileManager.default.createDirectory(
            at: output.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let result = try runner.run(
            "xcrun",
            arguments: ["simctl", "io", udid, "screenshot", output.path]
        )
        guard result.exitCode == 0 else {
            throw KujtoError(
                code: .process,
                message: LMsg(
                    sq: "Screenshoti deshtoi",
                    en: "Screenshot failed"
                )
            )
        }
    }
}
