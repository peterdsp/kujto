import ArgumentParser
import Foundation
import KujtoCore

struct ConfigCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "config",
        abstract: "Read and write .kujto/config.json.",
        subcommands: [Get.self, Set.self, Show.self]
    )

    struct Show: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "show",
            abstract: "Print the merged config (shared + local)."
        )

        func run() {
            let emitter = EventEmitter(mode: .human)
            runOrExit(emitter) {
                let config = try ConfigStore.load()
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                let data = try encoder.encode(config)
                print(String(data: data, encoding: .utf8) ?? "{}")
            }
        }
    }

    struct Get: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "get",
            abstract: "Read a single config field."
        )

        @Argument var key: String

        func run() {
            let emitter = EventEmitter(mode: .human)
            runOrExit(emitter) {
                let config = try ConfigStore.load()
                let value: String?
                switch key {
                case "workspace":       value = config.workspace
                case "project":         value = config.project
                case "scheme":          value = config.scheme
                case "configuration":   value = config.configuration
                case "platform":        value = config.platform
                case "simulatorName":   value = config.simulatorName
                case "simulatorUdid":   value = config.simulatorUdid
                case "derivedDataPath": value = config.derivedDataPath
                case "lang":            value = config.lang
                default:
                    throw KujtoError(
                        code: .invalidConfig,
                        message: LMsg(
                            sq: "Celes i panjohur: \(key)",
                            en: "Unknown key: \(key)"
                        )
                    )
                }
                if let value = value { print(value) }
            }
        }
    }

    struct Set: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "set",
            abstract: "Set one or more config fields."
        )

        @Option(name: .long) var workspace: String?
        @Option(name: .long) var project: String?
        @Option(name: .long) var scheme: String?
        @Option(name: .long) var configuration: String?
        @Option(name: .long) var platform: String?
        @Option(name: .long) var simulator: String?
        @Option(name: .long) var simulatorUdid: String?
        @Option(name: .long) var derivedDataPath: String?
        @Option(name: .long, help: "Persisted language preference (sq | en).")
        var lang: String?
        @Option(name: .long, help: "UI test scheme name for `kujto ui session start`.")
        var uiTestScheme: String?

        @Flag(name: .long, help: "Write to .kujto/config.local.json (machine-only).")
        var local: Bool = false

        func run() {
            let emitter = EventEmitter(mode: .human)
            runOrExit(emitter) {
                let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                let dir = cwd.appendingPathComponent(ConfigStore.directoryName)
                let file = dir.appendingPathComponent(local ? ConfigStore.localName : ConfigStore.sharedName)

                var current = KujtoConfig()
                if FileManager.default.fileExists(atPath: file.path) {
                    let data = try Data(contentsOf: file)
                    current = (try? JSONDecoder().decode(KujtoConfig.self, from: data)) ?? KujtoConfig()
                }

                if let workspace = workspace { current.workspace = workspace }
                if let project = project { current.project = project }
                if let scheme = scheme { current.scheme = scheme }
                if let configuration = configuration { current.configuration = configuration }
                if let platform = platform { current.platform = platform }
                if let simulator = simulator { current.simulatorName = simulator }
                if let simulatorUdid = simulatorUdid { current.simulatorUdid = simulatorUdid }
                if let derivedDataPath = derivedDataPath { current.derivedDataPath = derivedDataPath }
                if let lang = lang { current.lang = lang }
                if let uiTestScheme = uiTestScheme { current.uiTestScheme = uiTestScheme }

                try ConfigStore.save(current, at: cwd, local: local)
                emitter.emit(type: "config_saved", [
                    "path": .string(file.path),
                    "scope": .string(local ? "local" : "shared")
                ])
            }
        }
    }
}
