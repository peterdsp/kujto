import Foundation

public struct PhysicalDevice: Codable, Sendable {
    public let name: String
    public let udid: String
    public let platform: String?
    public let osVersion: String?
    public let state: String?
}

public final class DeviceController {
    private let runner: ProcessRunner

    public init(runner: ProcessRunner = ProcessRunner()) {
        self.runner = runner
    }

    /// `xcrun devicectl list devices` insists on writing JSON to a file, so
    /// we hand it a temp file, read it back, and clean up.
    public func listDevices() throws -> [PhysicalDevice] {
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("kujto-devicectl-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: tmp) }

        let result = try runner.run(
            "xcrun",
            arguments: ["devicectl", "list", "devices", "--json-output", tmp.path]
        )
        guard result.exitCode == 0 else {
            throw KujtoError(
                code: .deviceNotFound,
                message: LMsg(
                    sq: "devicectl deshtoi me kod \(result.exitCode)",
                    en: "devicectl failed with code \(result.exitCode)"
                )
            )
        }
        let data = try Data(contentsOf: tmp)
        let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let payload = obj?["result"] as? [String: Any]
        let devices = payload?["devices"] as? [[String: Any]] ?? []
        return makePhysicalDevices(devices)
    }

    /// Installs a built `.app` onto a physical device via devicectl. The
    /// most common failure modes (locked screen, untrusted host, missing
    /// profile, no dev team) are mapped to typed errors so agents and CI
    /// surfaces get a stable signal instead of raw stderr.
    public func install(appPath: String, deviceUdid: String) throws {
        let r = try ProcessRunner().run(
            "xcrun",
            arguments: ["devicectl", "device", "install", "app", "--device", deviceUdid, appPath]
        )
        if r.exitCode != 0 {
            throw mapDeviceError(stderr: r.stderr + "\n" + r.stdout, fallback: .appInstallFailed)
        }
    }

    public func launch(bundleId: String, deviceUdid: String) throws {
        let r = try ProcessRunner().run(
            "xcrun",
            arguments: ["devicectl", "device", "process", "launch", "--device", deviceUdid, bundleId]
        )
        if r.exitCode != 0 {
            throw mapDeviceError(stderr: r.stderr + "\n" + r.stdout, fallback: .appLaunchFailed)
        }
    }

    /// Pattern-matches the noisy devicectl error blob against the failure
    /// modes the case study flags as common. Adds an actionable recovery
    /// string in both languages.
    func mapDeviceError(stderr: String, fallback: KujtoError.Code) -> KujtoError {
        let blob = stderr.lowercased()
        if blob.contains("locked") || blob.contains("passcode") {
            return KujtoError(
                code: .deviceLocked,
                message: LMsg(sq: "Pajisja eshte e bllokuar.", en: "The device is locked."),
                recovery: LMsg(
                    sq: "Zhblloko pajisjen dhe provo perseri.",
                    en: "Unlock the device and try again."
                )
            )
        }
        if blob.contains("not trusted") || blob.contains("untrusted") || blob.contains("trust this computer") {
            return KujtoError(
                code: .deviceNotTrusted,
                message: LMsg(sq: "Pajisja nuk e ka besuar kete kompjuter.", en: "Device does not trust this computer."),
                recovery: LMsg(
                    sq: "Ne pajisje shtyp 'Trust' kur shfaqet dialogu, pastaj rifillo.",
                    en: "Tap 'Trust' on the device when prompted, then retry."
                )
            )
        }
        if blob.contains("provisioning") || blob.contains("entitlement") {
            return KujtoError(
                code: .provisioningFailed,
                message: LMsg(
                    sq: "Profili i provizionit nuk perputhet me pajisjen.",
                    en: "Provisioning profile mismatch."
                ),
                recovery: LMsg(
                    sq: "Sigurohu qe pajisja eshte regjistruar ne profilin e provizionit.",
                    en: "Ensure the device is registered in the provisioning profile."
                )
            )
        }
        if blob.contains("development team") || blob.contains("no team") || blob.contains("development_team") {
            return KujtoError(
                code: .noDevelopmentTeam,
                message: LMsg(
                    sq: "Asnje development team i specifikuar.",
                    en: "No development team specified."
                ),
                recovery: LMsg(
                    sq: "Konfiguro 'Signing & Capabilities > Team' ne Xcode.",
                    en: "Set 'Signing & Capabilities > Team' in Xcode."
                )
            )
        }
        if blob.contains("incompatible") || blob.contains("unsupported os") || blob.contains("minimumosversion") {
            return KujtoError(
                code: .deviceIncompatible,
                message: LMsg(
                    sq: "Pajisja nuk eshte e perputhshme me kete build.",
                    en: "Device is incompatible with this build."
                ),
                recovery: LMsg(
                    sq: "Verifiko deployment target dhe versionin e OS-it.",
                    en: "Check the deployment target and OS version."
                )
            )
        }
        if blob.contains("not connected") || blob.contains("disconnected") || blob.contains("not paired") {
            return KujtoError(
                code: .deviceNotFound,
                message: LMsg(
                    sq: "Pajisja nuk eshte e lidhur ose nuk eshte palidhur.",
                    en: "Device is not connected or not paired."
                ),
                recovery: LMsg(
                    sq: "Lidhe pajisjen me USB dhe ekzekuto 'kujto device list'.",
                    en: "Connect the device via USB and run 'kujto device list'."
                )
            )
        }
        // Unknown failure: keep the original stderr in the message so the
        // user (or the agent) can paste it into a search box. Trim to a
        // bounded length so we don't dump megabytes into an event.
        let snippet = String(stderr.prefix(800))
        return KujtoError(
            code: fallback,
            message: LMsg(
                sq: "devicectl deshtoi: \(snippet)",
                en: "devicectl failed: \(snippet)"
            )
        )
    }

    private func makePhysicalDevices(_ devices: [[String: Any]]) -> [PhysicalDevice] {
        return devices.compactMap { entry in
            let hardware = entry["hardwareProperties"] as? [String: Any]
            let deviceProps = entry["deviceProperties"] as? [String: Any]
            let connection = entry["connectionProperties"] as? [String: Any]
            let identifier = (entry["identifier"] as? String)
                ?? (hardware?["udid"] as? String)
                ?? ""
            let name = (deviceProps?["name"] as? String)
                ?? (hardware?["marketingName"] as? String)
                ?? identifier
            return PhysicalDevice(
                name: name,
                udid: identifier,
                platform: hardware?["platform"] as? String,
                osVersion: deviceProps?["osVersionNumber"] as? String,
                state: connection?["tunnelState"] as? String
            )
        }
    }
}
