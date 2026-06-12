import ArgumentParser
import Foundation
import KujtoCore

struct BuildCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "build",
        abstract: "Build the configured Xcode scheme via xcodebuild."
    )

    @OptionGroup var global: GlobalOptions

    @Option(name: .long, help: "Override scheme.")
    var scheme: String?

    @Option(name: .long, help: "Override configuration (Debug | Release).")
    var configuration: String?

    @Option(name: .long, help: "Simulator name for destination resolution.")
    var simulator: String?

    @Option(name: .long, help: "Simulator UDID for destination resolution.")
    var simulatorUdid: String?

    func run() {
        let emitter = global.makeEmitter()
        runOrExit(emitter) {
            var config = try global.loadConfig()
            if let scheme = scheme { config.scheme = scheme }
            if let configuration = configuration { config.configuration = configuration }
            if let simulator = simulator { config.simulatorName = simulator }
            if let simulatorUdid = simulatorUdid { config.simulatorUdid = simulatorUdid }

            // Resolve destination udid from explicit input → config → first available booted/any.
            let sim = SimulatorController()
            let udid: String?
            do {
                udid = try sim.resolveUdid(name: config.simulatorName, udid: config.simulatorUdid)
            } catch {
                udid = nil
            }

            let runner = BuildRunner(emitter: emitter)
            let result = try runner.build(config: config, simulatorUdid: udid, timeoutMs: global.timeoutMs)

            if !result.success {
                Foundation.exit(1)
            }
        }
    }
}
