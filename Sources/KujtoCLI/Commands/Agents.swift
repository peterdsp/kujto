import ArgumentParser
import Foundation
import KujtoCore

/// `kujto agents` reports which agent files are wired in the current directory.
/// Read-only sibling to `kujto wire`. The Studio agent panel reads the same model.
struct AgentsCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "agents",
        abstract: "List the wire state of agent files in the current directory."
    )

    @OptionGroup var global: GlobalOptions

    @Option(name: .long, help: "Directory to inspect. Defaults to the current working directory.")
    var target: String?

    func run() {
        let emitter = global.makeEmitter()
        runOrExit(emitter) {
            let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            let targetURL = target.map { URL(fileURLWithPath: $0) } ?? cwd
            let statuses = AgentExport.status(target: targetURL, root: KujtoRoot.locate())

            if global.json {
                emitter.emit(type: "agents", [
                    "target": .string(targetURL.path),
                    "statuses": .array(statuses.map { status in
                        .object([
                            "agent": .string(status.agent.rawValue),
                            "file": .string(status.agent.fileName),
                            "state": .string(status.state.rawValue),
                            "link_destination": status.linkDestination.map { .string($0) } ?? .null
                        ])
                    })
                ])
            } else {
                print("Agents in \(targetURL.path):")
                for status in statuses {
                    let marker: String
                    switch status.state {
                    case .linked:     marker = "✓"
                    case .foreign:    marker = "!"
                    case .notPresent: marker = "·"
                    }
                    var line = "  \(marker) \(status.agent.fileName): \(status.state.rawValue)"
                    if let dest = status.linkDestination { line += " -> \(dest)" }
                    print(line)
                }
            }
        }
    }
}
