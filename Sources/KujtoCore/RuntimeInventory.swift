import Foundation

/// A single iOS Simulator device known to CoreSimulator.
///
/// Parsed from `~/Library/Developer/CoreSimulator/Devices/<UDID>/device.plist`.
/// Kujto reads these directly rather than shelling out to `simctl` so we can
/// list simulators without leaving the sandbox - provided the user has
/// granted access to the CoreSimulator devices folder.
public struct LocalSimulator: Sendable, Hashable, Identifiable {
    public enum State: Sendable, Hashable {
        case booted, shutdown, unknown

        public var label: String {
            switch self {
            case .booted:   return "Booted"
            case .shutdown: return "Shutdown"
            case .unknown:  return "Unknown"
            }
        }
    }

    public var id: String { udid }
    public let udid: String
    public let name: String
    /// e.g. `iPhone-16-Pro`, extracted from
    /// `com.apple.CoreSimulator.SimDeviceType.iPhone-16-Pro`.
    public let deviceTypeSlug: String
    /// e.g. `iOS-26-0`, extracted from
    /// `com.apple.CoreSimulator.SimRuntime.iOS-26-0`.
    public let runtimeSlug: String
    public let state: State

    public init(udid: String, name: String, deviceTypeSlug: String, runtimeSlug: String, state: State) {
        self.udid = udid
        self.name = name
        self.deviceTypeSlug = deviceTypeSlug
        self.runtimeSlug = runtimeSlug
        self.state = state
    }

    /// Human name that reads well in the Codex, e.g. "iPhone 16 Pro · iOS 26.0".
    public var displayLine: String {
        let device = deviceTypeSlug.replacingOccurrences(of: "-", with: " ")
        let runtime = runtimeSlug.replacingOccurrences(of: "-", with: ".").replacingOccurrences(of: "iOS.", with: "iOS ")
        return "\(device) · \(runtime)"
    }
}

/// Reads a CoreSimulator devices directory and returns the discovered
/// simulators. Sandbox-safe as long as the caller opens security-scoped
/// access to `devicesRoot` before calling.
public enum SimulatorInventory {
    public static func load(devicesRoot: URL) -> [LocalSimulator] {
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(at: devicesRoot, includingPropertiesForKeys: [.isDirectoryKey]) else {
            return []
        }
        var out: [LocalSimulator] = []
        for entry in entries {
            let isDir = (try? entry.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            guard isDir else { continue }
            let plist = entry.appendingPathComponent("device.plist")
            guard let data = try? Data(contentsOf: plist),
                  let raw = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else {
                continue
            }
            if let device = parse(raw) { out.append(device) }
        }
        return out.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private static func parse(_ raw: [String: Any]) -> LocalSimulator? {
        guard let udid = raw["UDID"] as? String,
              let name = raw["name"] as? String else { return nil }
        let deviceTypeRaw = (raw["deviceType"] as? String) ?? ""
        let runtimeRaw = (raw["runtime"] as? String) ?? ""
        let deviceType = deviceTypeRaw.components(separatedBy: ".").last ?? deviceTypeRaw
        let runtime = runtimeRaw.components(separatedBy: ".").last ?? runtimeRaw
        let stateValue = raw["state"] as? Int ?? -1
        let state: LocalSimulator.State
        switch stateValue {
        case 3: state = .booted
        case 1: state = .shutdown
        default: state = .unknown
        }
        return LocalSimulator(
            udid: udid,
            name: name,
            deviceTypeSlug: deviceType,
            runtimeSlug: runtime,
            state: state
        )
    }
}

/// Text of a `simctl` command Kujto would run if it had process-launch
/// permission. Copy-and-run in Terminal is the interim workflow while the
/// SMAppService helper daemon isn't in place.
public enum SimctlCommand {
    public static func openURL(device: LocalSimulator, url: String) -> String {
        "xcrun simctl openurl \(device.udid) \(url)"
    }

    public static func boot(device: LocalSimulator) -> String {
        "xcrun simctl boot \(device.udid)"
    }

    public static func launch(device: LocalSimulator, bundleID: String) -> String {
        "xcrun simctl launch \(device.udid) \(bundleID)"
    }

    public static func screenshot(device: LocalSimulator, to path: String) -> String {
        "xcrun simctl io \(device.udid) screenshot \(path)"
    }
}
