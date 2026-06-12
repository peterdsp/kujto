import ArgumentParser
import Foundation
import KujtoCore

struct LogsCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "logs",
        abstract: "Stream logs from a launched app (or from a custom predicate)."
    )

    @OptionGroup var global: GlobalOptions

    @Argument(help: "App id from `kujto apps` (defaults to the most recent).")
    var appId: String?

    @Option(name: .long, help: "Simulator UDID (overrides app record).")
    var udid: String?

    @Option(name: .long, help: "Override the log predicate.")
    var predicate: String?

    func run() {
        let emitter = global.makeEmitter()
        runOrExit(emitter) {
            let store = RuntimeStore()
            let app: LaunchedApp?
            if let appId = appId {
                app = try store.find(id: appId)
            } else {
                app = try store.list().last
            }

            let resolvedUdid: String
            if let udid = udid {
                resolvedUdid = udid
            } else if let app = app {
                resolvedUdid = app.simulatorUdid
            } else {
                let sim = SimulatorController()
                let config = try global.loadConfig()
                resolvedUdid = try sim.resolveUdid(name: config.simulatorName, udid: config.simulatorUdid)
            }

            let streamer = LogStreamer(emitter: emitter)
            try streamer.stream(
                udid: resolvedUdid,
                processName: app?.processName,
                bundleId: app?.bundleId,
                customPredicate: predicate,
                timeoutMs: global.timeoutMs
            )
        }
    }
}
