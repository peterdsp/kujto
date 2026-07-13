import ArgumentParser
import Foundation
import KujtoCore

struct SimulatorCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "simulator",
        abstract: "List, boot, erase, screenshot, and control iOS simulators.",
        subcommands: [
            List.self, Boot.self, Shutdown.self, Erase.self, Screenshot.self,
            Create.self, Delete.self, Appearance.self, Location.self,
            StatusBar.self, Push.self, Privacy.self, Clipboard.self, Container.self
        ]
    )

    struct List: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "list",
            abstract: "List available simulators."
        )

        @OptionGroup var global: GlobalOptions

        @Option(name: .long, help: "Filter by platform (iOS, watchOS, tvOS, visionOS).")
        var platform: String?

        func run() {
            let emitter = global.makeEmitter()
            runOrExit(emitter) {
                let sim = SimulatorController()
                let devices = try sim.listDevices(platform: platform)
                if global.json {
                    for d in devices {
                        emitter.emit(type: "simulator_event", [
                            "kind": .string("device"),
                            "name": .string(d.name),
                            "udid": .string(d.udid),
                            "state": .string(d.state),
                            "runtime": d.runtime.map { .string($0) } ?? .null
                        ])
                    }
                } else {
                    let nameWidth = max(20, devices.map { $0.name.count }.max() ?? 20)
                    func pad(_ s: String, _ width: Int) -> String {
                        if s.count >= width { return s }
                        return s + String(repeating: " ", count: width - s.count)
                    }
                    print("\(pad("NAME", nameWidth))  \(pad("UDID", 36))  \(pad("STATE", 10))  RUNTIME")
                    for d in devices {
                        print("\(pad(d.name, nameWidth))  \(pad(d.udid, 36))  \(pad(d.state, 10))  \(d.runtime ?? "")")
                    }
                }
            }
        }
    }

    struct Boot: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "boot",
            abstract: "Boot a simulator by name or UDID."
        )

        @OptionGroup var global: GlobalOptions
        @Argument(help: "Simulator name (e.g. \"iPhone 16\") or UDID.") var identifier: String

        func run() {
            let emitter = global.makeEmitter()
            runOrExit(emitter) {
                let sim = SimulatorController()
                let udid = try sim.resolveUdid(name: identifier, udid: identifier)
                try sim.boot(udid: udid)
                emitter.emit(type: "simulator_event", [
                    "kind": .string("booted"),
                    "udid": .string(udid)
                ])
            }
        }
    }

    struct Shutdown: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "shutdown",
            abstract: "Shut down a simulator."
        )

        @OptionGroup var global: GlobalOptions
        @Argument(help: "Simulator name or UDID.") var identifier: String

        func run() {
            let emitter = global.makeEmitter()
            runOrExit(emitter) {
                let sim = SimulatorController()
                let udid = try sim.resolveUdid(name: identifier, udid: identifier)
                _ = try sim.shutdown(udid: udid)
                emitter.emit(type: "simulator_event", [
                    "kind": .string("shutdown"),
                    "udid": .string(udid)
                ])
            }
        }
    }

    struct Erase: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "erase",
            abstract: "Erase a simulator (destructive)."
        )

        @OptionGroup var global: GlobalOptions
        @Argument(help: "Simulator name or UDID.") var identifier: String
        @Flag(name: .shortAndLong, help: "Skip the confirmation prompt.")
        var yes: Bool = false

        func run() {
            let emitter = global.makeEmitter()
            runOrExit(emitter) {
                if !yes {
                    print("Erase will wipe all data. Re-run with --yes to confirm.")
                    Foundation.exit(2)
                }
                let sim = SimulatorController()
                let udid = try sim.resolveUdid(name: identifier, udid: identifier)
                _ = try sim.erase(udid: udid)
                emitter.emit(type: "simulator_event", [
                    "kind": .string("erased"),
                    "udid": .string(udid)
                ])
            }
        }
    }

    struct Screenshot: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "screenshot",
            abstract: "Capture a PNG screenshot from a simulator."
        )

        @OptionGroup var global: GlobalOptions
        @Option(name: .long, help: "Simulator name or UDID.") var identifier: String?
        @Option(name: .long, help: "Output PNG path.") var output: String

        func run() {
            let emitter = global.makeEmitter()
            runOrExit(emitter) {
                let sim = SimulatorController()
                let udid: String
                if let identifier = identifier {
                    udid = try sim.resolveUdid(name: identifier, udid: identifier)
                } else {
                    let config = try global.loadConfig()
                    udid = try sim.resolveUdid(name: config.simulatorName, udid: config.simulatorUdid)
                }
                try sim.screenshot(udid: udid, output: URL(fileURLWithPath: output))
                emitter.emit(type: "ui_snapshot", [
                    "screenshot": .string(output),
                    "tree": .null
                ])
            }
        }
    }

    struct Create: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "create",
            abstract: "Create a new simulator (simctl create)."
        )
        @OptionGroup var global: GlobalOptions
        @Option(name: .long, help: "Name for the new simulator.") var name: String
        @Option(name: .long, help: "Device type (e.g. \"iPhone 16\" or a com.apple.CoreSimulator... id).") var deviceType: String
        @Option(name: .long, help: "Runtime id or name (e.g. iOS17.5). Defaults to the newest installed.") var runtime: String?

        func run() {
            let emitter = global.makeEmitter()
            runOrExit(emitter) {
                let udid = try SimulatorController().createSimulator(name: name, deviceType: deviceType, runtime: runtime)
                if global.json {
                    emitter.emit(type: "simulator_event", [
                        "kind": .string("created"),
                        "name": .string(name),
                        "udid": .string(udid)
                    ])
                } else {
                    print(udid)
                }
            }
        }
    }

    struct Delete: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "delete",
            abstract: "Delete a simulator by name or UDID (destructive)."
        )
        @OptionGroup var global: GlobalOptions
        @Argument(help: "Simulator name or UDID.") var identifier: String
        @Flag(name: .shortAndLong, help: "Skip the confirmation prompt.") var yes: Bool = false

        func run() {
            let emitter = global.makeEmitter()
            runOrExit(emitter) {
                if !yes {
                    print("Delete removes the simulator and its data. Re-run with --yes to confirm.")
                    Foundation.exit(2)
                }
                let sim = SimulatorController()
                let udid = try sim.resolveUdid(name: identifier, udid: identifier)
                try sim.deleteSimulator(target: udid)
                emitter.emit(type: "simulator_event", [
                    "kind": .string("deleted"),
                    "udid": .string(udid)
                ])
            }
        }
    }

    struct Appearance: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "appearance",
            abstract: "Set the simulator UI style: light | dark."
        )
        @OptionGroup var global: GlobalOptions
        @Argument(help: "light | dark.") var style: String
        @Option(name: .long, help: "Simulator name or UDID (defaults to the configured/booted one).") var identifier: String?

        func run() {
            let emitter = global.makeEmitter()
            runOrExit(emitter) {
                guard style == "light" || style == "dark" else {
                    throw KujtoError(
                        code: .unknownArgument,
                        message: LMsg(sq: "Stili duhet te jete 'light' ose 'dark'.", en: "Style must be 'light' or 'dark'.")
                    )
                }
                let udid = try SimCLI.resolveUdid(identifier, global)
                try SimulatorController().setAppearance(udid: udid, style: style)
                emitter.emit(type: "simulator_event", [
                    "kind": .string("appearance"),
                    "udid": .string(udid),
                    "style": .string(style)
                ])
            }
        }
    }

    struct Location: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "location",
            abstract: "Set, run, or clear the simulated GPS location."
        )
        @OptionGroup var global: GlobalOptions
        @Option(name: .long, help: "Latitude,longitude, e.g. 37.7749,-122.4194.") var set: String?
        @Option(name: .long, help: "Named scenario (see `xcrun simctl location <udid> list`).") var scenario: String?
        @Flag(name: .long, help: "Clear any simulated location.") var clear: Bool = false
        @Option(name: .long, help: "Simulator name or UDID.") var identifier: String?

        func run() {
            let emitter = global.makeEmitter()
            runOrExit(emitter) {
                let sim = SimulatorController()
                let udid = try SimCLI.resolveUdid(identifier, global)
                if clear {
                    try sim.clearLocation(udid: udid)
                    emitter.emit(type: "simulator_event", ["kind": .string("location_clear"), "udid": .string(udid)])
                } else if let scenario = scenario {
                    try sim.runLocationScenario(udid: udid, scenario: scenario)
                    emitter.emit(type: "simulator_event", ["kind": .string("location_run"), "udid": .string(udid), "scenario": .string(scenario)])
                } else if let set = set {
                    let parts = set.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                    guard parts.count == 2, let lat = Double(parts[0]), let lon = Double(parts[1]) else {
                        throw KujtoError(
                            code: .unknownArgument,
                            message: LMsg(sq: "--set kerkon 'lat,lon'.", en: "--set expects 'lat,lon'.")
                        )
                    }
                    try sim.setLocation(udid: udid, latitude: lat, longitude: lon)
                    emitter.emit(type: "simulator_event", [
                        "kind": .string("location_set"), "udid": .string(udid),
                        "latitude": .double(lat), "longitude": .double(lon)
                    ])
                } else {
                    throw KujtoError(
                        code: .unknownArgument,
                        message: LMsg(sq: "Jep --set, --scenario ose --clear.", en: "Provide --set, --scenario, or --clear.")
                    )
                }
            }
        }
    }

    struct StatusBar: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "status-bar",
            abstract: "Override or clear the status bar (time, battery, network)."
        )
        @OptionGroup var global: GlobalOptions
        @Flag(name: .long, help: "Clear all overrides instead of setting them.") var clear: Bool = false
        @Option(name: .long, help: "Fixed time string, e.g. 9:41.") var time: String?
        @Option(name: .long, help: "Data network: wifi, 3g, 4g, lte, 5g, ...") var dataNetwork: String?
        @Option(name: .long, help: "Wi-Fi bars 0-3.") var wifiBars: Int?
        @Option(name: .long, help: "Cellular bars 0-4.") var cellularBars: Int?
        @Option(name: .long, help: "Battery state: charging, charged, discharging.") var batteryState: String?
        @Option(name: .long, help: "Battery level 0-100.") var batteryLevel: Int?
        @Option(name: .long, help: "Simulator name or UDID.") var identifier: String?

        func run() {
            let emitter = global.makeEmitter()
            runOrExit(emitter) {
                let sim = SimulatorController()
                let udid = try SimCLI.resolveUdid(identifier, global)
                if clear {
                    try sim.clearStatusBar(udid: udid)
                    emitter.emit(type: "simulator_event", ["kind": .string("status_bar_clear"), "udid": .string(udid)])
                    return
                }
                let args = SimctlArgs.statusBarOverride(
                    udid: udid, time: time, dataNetwork: dataNetwork, wifiBars: wifiBars,
                    cellularBars: cellularBars, batteryState: batteryState, batteryLevel: batteryLevel
                )
                // "override" with no flags is a simctl usage error; guard here.
                guard args.count > 4 else {
                    throw KujtoError(
                        code: .unknownArgument,
                        message: LMsg(sq: "Jep te pakten nje flamur override (ose --clear).", en: "Provide at least one override flag (or --clear).")
                    )
                }
                try sim.overrideStatusBar(args)
                emitter.emit(type: "simulator_event", ["kind": .string("status_bar_override"), "udid": .string(udid)])
            }
        }
    }

    struct Push: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "push",
            abstract: "Send a simulated push notification from a JSON payload."
        )
        @OptionGroup var global: GlobalOptions
        @Option(name: .long, help: "Path to the APNs JSON payload ('-' for stdin).") var payload: String
        @Option(name: .long, help: "Target bundle id (optional if the payload sets it).") var bundleId: String?
        @Option(name: .long, help: "Simulator name or UDID.") var identifier: String?

        func run() {
            let emitter = global.makeEmitter()
            runOrExit(emitter) {
                let udid = try SimCLI.resolveUdid(identifier, global)
                try SimulatorController().sendPush(udid: udid, bundleId: bundleId, payloadPath: payload)
                emitter.emit(type: "simulator_event", [
                    "kind": .string("push"), "udid": .string(udid),
                    "bundle_id": bundleId.map { .string($0) } ?? .null
                ])
            }
        }
    }

    struct Privacy: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "privacy",
            abstract: "Grant, revoke, or reset an app's privacy permission."
        )
        @OptionGroup var global: GlobalOptions
        @Argument(help: "grant | revoke | reset.") var action: String
        @Argument(help: "Service (e.g. photos, location, contacts, all).") var service: String
        @Option(name: .long, help: "Bundle id (required for grant/revoke).") var bundleId: String?
        @Option(name: .long, help: "Simulator name or UDID.") var identifier: String?

        func run() {
            let emitter = global.makeEmitter()
            runOrExit(emitter) {
                guard ["grant", "revoke", "reset"].contains(action) else {
                    throw KujtoError(
                        code: .unknownArgument,
                        message: LMsg(sq: "Veprimi duhet te jete grant, revoke ose reset.", en: "Action must be grant, revoke, or reset.")
                    )
                }
                if (action == "grant" || action == "revoke") && (bundleId?.isEmpty ?? true) {
                    throw KujtoError(
                        code: .unknownArgument,
                        message: LMsg(sq: "\(action) kerkon --bundle-id.", en: "\(action) requires --bundle-id.")
                    )
                }
                let udid = try SimCLI.resolveUdid(identifier, global)
                try SimulatorController().setPrivacy(udid: udid, action: action, service: service, bundleId: bundleId)
                emitter.emit(type: "simulator_event", [
                    "kind": .string("privacy"), "udid": .string(udid),
                    "action": .string(action), "service": .string(service)
                ])
            }
        }
    }

    struct Clipboard: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "clipboard",
            abstract: "Copy text to, or print, the simulator pasteboard."
        )
        @OptionGroup var global: GlobalOptions
        @Option(name: .long, help: "Text to copy onto the simulator pasteboard.") var copy: String?
        @Flag(name: .long, help: "Print the simulator pasteboard contents.") var paste: Bool = false
        @Option(name: .long, help: "Simulator name or UDID.") var identifier: String?

        func run() {
            let emitter = global.makeEmitter()
            runOrExit(emitter) {
                let sim = SimulatorController()
                let udid = try SimCLI.resolveUdid(identifier, global)
                if let copy = copy {
                    try sim.copyToPasteboard(udid: udid, text: copy)
                    emitter.emit(type: "simulator_event", ["kind": .string("clipboard_copy"), "udid": .string(udid)])
                } else if paste {
                    let contents = try sim.pasteboardContents(udid: udid)
                    if global.json {
                        emitter.emit(type: "simulator_event", ["kind": .string("clipboard_paste"), "udid": .string(udid), "contents": .string(contents)])
                    } else {
                        print(contents, terminator: "")
                    }
                } else {
                    throw KujtoError(
                        code: .unknownArgument,
                        message: LMsg(sq: "Jep --copy TEXT ose --paste.", en: "Provide --copy TEXT or --paste.")
                    )
                }
            }
        }
    }

    struct Container: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "container",
            abstract: "Print an installed app's container path (get_app_container)."
        )
        @OptionGroup var global: GlobalOptions
        @Option(name: .long, help: "Bundle id of the installed app.") var bundleId: String
        @Option(name: .long, help: "Container: app | data | groups | <group id> (default app).") var kind: String?
        @Option(name: .long, help: "Simulator name or UDID.") var identifier: String?

        func run() {
            let emitter = global.makeEmitter()
            runOrExit(emitter) {
                let udid = try SimCLI.resolveUdid(identifier, global)
                let path = try SimulatorController().appContainer(udid: udid, bundleId: bundleId, kind: kind)
                if global.json {
                    emitter.emit(type: "simulator_event", [
                        "kind": .string("container"), "udid": .string(udid),
                        "bundle_id": .string(bundleId), "path": .string(path)
                    ])
                } else {
                    print(path)
                }
            }
        }
    }
}

/// Shared UDID resolution for the device-state subcommands: an explicit
/// name/UDID argument wins, otherwise fall back to the configured
/// simulator (matching how `simulator screenshot` behaves).
enum SimCLI {
    static func resolveUdid(_ identifier: String?, _ global: GlobalOptions) throws -> String {
        let sim = SimulatorController()
        if let id = identifier, !id.isEmpty {
            return try sim.resolveUdid(name: id, udid: id)
        }
        let config = try global.loadConfig()
        return try sim.resolveUdid(name: config.simulatorName, udid: config.simulatorUdid)
    }
}
