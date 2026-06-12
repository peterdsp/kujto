import ArgumentParser
import Foundation
import KujtoCore

struct SimulatorCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "simulator",
        abstract: "List, boot, erase, and screenshot iOS simulators.",
        subcommands: [List.self, Boot.self, Shutdown.self, Erase.self, Screenshot.self]
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
}
