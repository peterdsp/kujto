import ArgumentParser
import Foundation
import KujtoCore

struct UnwireCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "unwire",
        abstract: "Remove Kujto symlinks from a repository."
    )

    @Option(name: .long, help: "Target repository path (defaults to cwd).")
    var target: String?

    @Flag(name: .long, help: "Emit NDJSON events.")
    var json: Bool = false

    func run() {
        let emitter = EventEmitter(mode: json ? .ndjson : .human)
        runOrExit(emitter) {
            let targetURL: URL
            if let target = target {
                targetURL = URL(fileURLWithPath: target)
            } else {
                targetURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            }
            let service = WireService(root: KujtoRoot.locate(), emitter: emitter)
            try service.unwire(at: targetURL)
        }
    }
}
