import ArgumentParser
import Foundation
import KujtoCore

struct DeviceCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "device",
        abstract: "Physical device controls (devicectl wrapper).",
        subcommands: [List.self, Install.self, Launch.self]
    )

    struct List: ParsableCommand {
        static let configuration = CommandConfiguration(commandName: "list", abstract: "List connected devices.")
        @OptionGroup var global: GlobalOptions

        func run() {
            let emitter = global.makeEmitter()
            runOrExit(emitter) {
                let devices = try DeviceController().listDevices()
                if global.json {
                    for d in devices {
                        emitter.emit(NDJSONEvent(type: "device_event", [
                            "kind": .string("device"),
                            "name": .string(d.name),
                            "udid": .string(d.udid),
                            "platform": d.platform.map { .string($0) } ?? .null,
                            "os_version": d.osVersion.map { .string($0) } ?? .null,
                            "state": d.state.map { .string($0) } ?? .null
                        ]))
                    }
                } else {
                    if devices.isEmpty { print("(no devices connected)") }
                    func pad(_ s: String, _ w: Int) -> String {
                        s.count >= w ? s : s + String(repeating: " ", count: w - s.count)
                    }
                    let nameW = max(20, devices.map { $0.name.count }.max() ?? 20)
                    print("\(pad("NAME", nameW))  \(pad("UDID", 38))  PLATFORM   OS")
                    for d in devices {
                        print("\(pad(d.name, nameW))  \(pad(d.udid, 38))  \(pad(d.platform ?? "?", 10)) \(d.osVersion ?? "")")
                    }
                }
            }
        }
    }

    struct Install: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "install",
            abstract: "Install an app on a connected device via devicectl."
        )
        @OptionGroup var global: GlobalOptions

        @Option(name: .long, help: "Device UDID (see `kujto device list`).")
        var udid: String

        @Option(name: .long, help: "Path to the .app bundle.")
        var appPath: String

        func run() {
            let emitter = global.makeEmitter()
            runOrExit(emitter) {
                try DeviceController().install(appPath: appPath, deviceUdid: udid)
                emitter.emit(type: "device_event", [
                    "kind": .string("installed"),
                    "udid": .string(udid),
                    "app_path": .string(appPath)
                ])
            }
        }
    }

    struct Launch: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "launch",
            abstract: "Launch an installed app on a device via devicectl."
        )
        @OptionGroup var global: GlobalOptions

        @Option(name: .long, help: "Device UDID.")
        var udid: String

        @Option(name: .long, help: "Bundle identifier of the installed app.")
        var bundleId: String

        func run() {
            let emitter = global.makeEmitter()
            runOrExit(emitter) {
                try DeviceController().launch(bundleId: bundleId, deviceUdid: udid)
                emitter.emit(type: "device_event", [
                    "kind": .string("launched"),
                    "udid": .string(udid),
                    "bundle_id": .string(bundleId)
                ])
            }
        }
    }
}
