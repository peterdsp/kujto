import ArgumentParser
import Foundation
import KujtoCore

struct WireCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "wire",
        abstract: "Link AGENTS.md aliases into a repository."
    )

    @Option(name: .long, help: "Target repository path (defaults to cwd).")
    var target: String?

    @Flag(name: .long, help: "Also link the memory/ directory.")
    var memory: Bool = false

    @Flag(name: .long, help: "Copy files instead of symlinking.")
    var copy: Bool = false

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
            try service.wire(WireService.Options(target: targetURL, wireMemory: memory, copyFiles: copy))
        }
    }
}
