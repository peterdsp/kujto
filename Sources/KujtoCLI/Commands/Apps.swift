import ArgumentParser
import Foundation
import KujtoCore

struct AppsCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "apps",
        abstract: "List apps launched by `kujto run`."
    )

    @OptionGroup var global: GlobalOptions

    func run() {
        let emitter = global.makeEmitter()
        runOrExit(emitter) {
            let apps = try RuntimeStore().list()
            if global.json {
                for app in apps {
                    emitter.emit(NDJSONEvent(type: "app_record", [
                        "id": .string(app.id),
                        "bundle_id": .string(app.bundleId),
                        "process": .string(app.processName),
                        "udid": .string(app.simulatorUdid),
                        "app_path": .string(app.appPath),
                        "launched_at": .string(app.launchedAt)
                    ]))
                }
            } else {
                if apps.isEmpty { print("(no apps launched via `kujto run`)") }
                for app in apps {
                    print("\(app.id)  \(app.bundleId)  \(app.simulatorUdid)  (\(app.launchedAt))")
                }
            }
        }
    }
}
