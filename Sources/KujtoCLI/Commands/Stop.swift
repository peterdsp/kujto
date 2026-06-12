import ArgumentParser
import Foundation
import KujtoCore

struct StopCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "stop",
        abstract: "Stop a launched app (and its log stream if tracked)."
    )

    @OptionGroup var global: GlobalOptions

    @Argument(help: "App id from `kujto apps` (defaults to the most recent).")
    var appId: String?

    @Flag(name: .long, help: "Stop all launched apps.")
    var all: Bool = false

    func run() {
        let emitter = global.makeEmitter()
        runOrExit(emitter) {
            let store = RuntimeStore()
            let launcher = AppLauncher(emitter: emitter)
            var toStop: [LaunchedApp] = []
            if all {
                toStop = try store.list()
            } else if let appId = appId, let app = try store.find(id: appId) {
                toStop = [app]
            } else if let last = try store.list().last {
                toStop = [last]
            }
            if toStop.isEmpty {
                emitter.emitError(KujtoError(
                    code: .appLaunchFailed,
                    message: LMsg(
                        sq: "Asnje aplikacion i ndjekur per t'u ndalur",
                        en: "No tracked apps to stop"
                    )
                ))
                Foundation.exit(2)
            }
            for app in toStop {
                try launcher.terminate(bundleId: app.bundleId, udid: app.simulatorUdid)
                if let pid = app.logStreamPid {
                    kill(pid_t(pid), SIGTERM)
                }
                _ = try store.remove(id: app.id)
                if !global.json {
                    print("✓ stopped \(app.bundleId) (\(app.id))")
                }
            }
        }
    }
}
