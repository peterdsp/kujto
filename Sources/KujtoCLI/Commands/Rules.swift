import ArgumentParser
import Foundation
import KujtoCore

/// `kujto rules <file>` is the CLI face of the "Before You Touch This File"
/// screen: it resolves a path against file-scoped memory and prints the rules
/// that apply, most specific first.
struct RulesCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "rules",
        abstract: "Show the memory and skill rules that apply to a file."
    )

    @OptionGroup var global: GlobalOptions

    @Argument(help: "Repo-relative path of the file you are about to edit.")
    var file: String

    func run() {
        let emitter = global.makeEmitter()
        runOrExit(emitter) {
            let root = KujtoRoot.locate()
            let index = try RuleIndex.load(root: root)
            let matches = index.resolve(file: file)

            if global.json {
                emitter.emit(type: "rules", [
                    "file": .string(file),
                    "matches": .array(matches.map { match in
                        .object([
                            "path": .string(match.rule.path),
                            "title": .string(match.rule.title),
                            "glob": .string(match.glob),
                            "kind": .string(match.rule.kind.rawValue),
                            "risk": .array(match.rule.risk.map { .string($0) }),
                            "score": .int(match.score)
                        ])
                    })
                ])
            } else if matches.isEmpty {
                print("No file-scoped rules match \(file).")
                print("Base memory still applies. See memory/MEMORY.md.")
            } else {
                print("Rules for \(file):")
                for match in matches {
                    let risk = match.rule.risk.isEmpty ? "" : "  [risk: \(match.rule.risk.joined(separator: ", "))]"
                    print("  • \(match.rule.title)\(risk)")
                    print("      \(match.rule.path)  (matched \(match.glob))")
                }
            }
        }
    }
}
