import ArgumentParser
import Foundation
import KujtoCore

struct TestCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "test",
        abstract: "Run unit and UI tests, capture .xcresult, emit test_failure events."
    )

    @OptionGroup var global: GlobalOptions

    @Option(name: .long, help: "Override scheme.")
    var scheme: String?

    @Option(name: .long, help: "Override simulator UDID.")
    var simulatorUdid: String?

    @Option(name: .long, help: "Override simulator name.")
    var simulator: String?

    @Option(name: .long, help: "Override the result bundle path (defaults to artifact store).")
    var resultBundle: String?

    func run() {
        let emitter = global.makeEmitter()
        runOrExit(emitter) {
            var config = try global.loadConfig()
            if let scheme = scheme { config.scheme = scheme }
            if let simulator = simulator { config.simulatorName = simulator }
            if let simulatorUdid = simulatorUdid { config.simulatorUdid = simulatorUdid }

            let sim = SimulatorController()
            let udid = try? sim.resolveUdid(name: config.simulatorName, udid: config.simulatorUdid)

            let store = try ArtifactStore()
            let bundleURL: URL
            if let resultBundle = resultBundle {
                bundleURL = URL(fileURLWithPath: resultBundle)
            } else {
                bundleURL = store.resultBundle
            }

            let runner = TestRunner(emitter: emitter)
            let summary = try runner.test(config: config, simulatorUdid: udid, resultBundle: bundleURL, timeoutMs: global.timeoutMs)

            if !global.json {
                print("Tests: \(summary.passed) passed, \(summary.failed) failed, \(summary.skipped) skipped, total \(summary.total) (\(summary.durationMs)ms)")
                print("Result bundle: \(bundleURL.path)")
            }
            if summary.failed > 0 { Foundation.exit(1) }
        }
    }
}
