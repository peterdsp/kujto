import ArgumentParser
import Foundation
import KujtoCore

/// `kujto debt` is the CLI face of Repo Sentiment: a single memory-debt
/// heartbeat with a breakdown that explains every point. Derived only from real
/// signals (lint, conflicts, stale rules, overrides), never a vanity number.
struct DebtCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "debt",
        abstract: "Report memory debt: a heartbeat leaders can watch, with its inputs explained."
    )

    @OptionGroup var global: GlobalOptions

    @Option(name: .long, help: "Repo root. Defaults to the current directory.")
    var root: String?

    @Option(name: .long, help: "Days before a rule's last commit counts as stale.")
    var staleDays: Int = 180

    @Option(name: .long, help: "Ledger JSON path. Active overrides count toward debt when given.")
    var ledger: String?

    func run() {
        let emitter = global.makeEmitter()
        runOrExit(emitter) {
            let repo = root.map { URL(fileURLWithPath: $0) }
                ?? URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

            var overrides = 0
            if let ledger {
                let store = RuleEventLedger(fileURL: URL(fileURLWithPath: ledger))
                overrides = store.activeOverrides(forRepo: repo.path).count
            }

            let debt = try MemoryDebtScanner.assess(root: repo, overrideCount: overrides, staleDays: staleDays)

            if global.json {
                emitter.emit(type: "debt", [
                    "score": .int(debt.score),
                    "grade": .string(debt.grade.rawValue),
                    "summary": .string(debt.summary),
                    "components": .array(debt.components.map { component in
                        .object([
                            "name": .string(component.name),
                            "count": .int(component.count),
                            "points": .int(component.points),
                            "note": .string(component.note)
                        ])
                    })
                ])
            } else {
                print("Memory debt: \(debt.grade.label) (\(debt.score)/100)")
                print("  \(debt.summary)")
                if debt.components.isEmpty {
                    print("  Nothing owed. Memory reads clean.")
                } else {
                    print("  Breakdown:")
                    for component in debt.components {
                        print("    \(component.name): \(component.count) (+\(component.points)) - \(component.note)")
                    }
                }
            }

            // Non-zero on heavy debt so a dashboard or CI can flag it.
            Foundation.exit(debt.grade == .heavy ? 1 : 0)
        }
    }
}
