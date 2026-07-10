import ArgumentParser
import Foundation
import KujtoCore

/// `kujto history <rule-file>` is the CLI face of Governance Rewind: it traces
/// a memory or skill file through local git, showing when it was introduced and
/// how its risk tags and applies_to globs changed over time.
struct HistoryCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "history",
        abstract: "Trace a memory rule's git history: introduction, risk changes, and glob changes."
    )

    @OptionGroup var global: GlobalOptions

    @Argument(help: "Repo-relative path of the memory or skill file to trace.")
    var ruleFile: String

    @Option(name: .long, help: "Repo root. Defaults to the current directory.")
    var root: String?

    @Option(name: .long, help: "Maximum number of revisions to walk.")
    var limit: Int = 50

    func run() {
        let emitter = global.makeEmitter()
        let repo = root.map { URL(fileURLWithPath: $0) }
            ?? URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let revisions = RuleHistoryScanner.history(forRule: ruleFile, in: repo, limit: limit)

        if global.json {
            emitter.emit(type: "history", [
                "file": .string(ruleFile),
                "revision_count": .int(revisions.count),
                "revisions": .array(revisions.map { rev in
                    .object([
                        "commit": .string(rev.commit),
                        "author": .string(rev.author),
                        "date": .string(rev.date),
                        "subject": .string(rev.subject),
                        "risk": .array(rev.risk.map { .string($0) }),
                        "applies_to": .array(rev.appliesTo.map { .string($0) })
                    ])
                })
            ])
        } else if revisions.isEmpty {
            print("No git history for \(ruleFile). Is it committed, and is this a git repo?")
        } else {
            print("History of \(ruleFile) (newest first):")
            for rev in revisions {
                let risk = rev.risk.isEmpty ? "no risk" : "risk: \(rev.risk.joined(separator: ", "))"
                print("  \(rev.commit)  \(rev.date)  \(rev.author)")
                print("      \(rev.subject)")
                print("      \(risk); globs: \(rev.appliesTo.isEmpty ? "none" : rev.appliesTo.joined(separator: ", "))")
            }
            let changes = RuleHistoryScanner.changePoints(in: revisions)
            if !changes.isEmpty {
                print("")
                print("Risk or glob changes:")
                for change in changes {
                    print("  \(change.older.commit) -> \(change.newer.commit) on \(change.newer.date)")
                }
            }
        }

        Foundation.exit(0)
    }
}
