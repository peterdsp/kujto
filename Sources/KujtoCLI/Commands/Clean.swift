import ArgumentParser
import Foundation
import KujtoCore

struct CleanCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "clean",
        abstract: "Remove derived data and (optionally) the artifact store."
    )

    @OptionGroup var global: GlobalOptions

    @Flag(name: .long, help: "Also clear .kujto/artifacts/.")
    var artifacts: Bool = false

    @Flag(name: .long, help: "Also clear .kujto/runtime/.")
    var runtime: Bool = false

    func run() {
        let emitter = global.makeEmitter()
        runOrExit(emitter) {
            let config = try global.loadConfig()
            let derived = config.derivedDataPath ?? ".kujto/DerivedData"
            try removeIfPresent(URL(fileURLWithPath: derived), label: "derived_data", emitter: emitter)

            let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            if artifacts {
                try removeIfPresent(
                    cwd.appendingPathComponent(".kujto").appendingPathComponent("artifacts"),
                    label: "artifacts",
                    emitter: emitter
                )
            }
            if runtime {
                try removeIfPresent(
                    cwd.appendingPathComponent(".kujto").appendingPathComponent("runtime"),
                    label: "runtime",
                    emitter: emitter
                )
            }
        }
    }

    private func removeIfPresent(_ url: URL, label: String, emitter: EventEmitter) throws {
        guard FileManager.default.fileExists(atPath: url.path) else {
            emitter.emit(type: "clean", ["target": .string(label), "status": .string("absent")])
            return
        }
        try FileManager.default.removeItem(at: url)
        emitter.emit(type: "clean", ["target": .string(label), "path": .string(url.path), "status": .string("removed")])
    }
}
