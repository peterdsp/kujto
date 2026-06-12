import ArgumentParser
import Foundation
import KujtoCore

struct ContextCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "context",
        abstract: "Inspect the current project context (workspaces, schemes, config)."
    )

    @OptionGroup var global: GlobalOptions

    func run() {
        let emitter = global.makeEmitter()
        runOrExit(emitter) {
            let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            let discovery = ProjectDiscovery()
            let report = try discovery.discover(at: cwd)
            let config = (try? global.loadConfig(at: cwd)) ?? KujtoConfig()

            if global.json {
                emitter.emit(type: "context", [
                    "cwd": .string(report.cwd),
                    "workspaces": .array(report.workspaces.map { .string($0) }),
                    "projects": .array(report.projects.map { .string($0) }),
                    "schemes": .array(report.schemes.map { .string($0) }),
                    "configurations": .array(report.configurations.map { .string($0) }),
                    "config_workspace": config.workspace.map { .string($0) } ?? .null,
                    "config_scheme": config.scheme.map { .string($0) } ?? .null,
                    "config_simulator_name": config.simulatorName.map { .string($0) } ?? .null,
                    "lang": .string(Lang.current.rawValue)
                ])
            } else {
                print("cwd:            \(report.cwd)")
                print("workspaces:     \(report.workspaces.joined(separator: ", "))")
                print("projects:       \(report.projects.joined(separator: ", "))")
                print("schemes:        \(report.schemes.joined(separator: ", "))")
                print("configurations: \(report.configurations.joined(separator: ", "))")
                if let scheme = config.scheme {
                    print("config.scheme:  \(scheme)")
                }
                if let sim = config.simulatorName {
                    print("config.sim:     \(sim)")
                }
                print("lang:           \(Lang.current.rawValue)")
            }
        }
    }
}
