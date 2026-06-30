import ArgumentParser
import Foundation
import KujtoCore

/// `kujto lint` runs deterministic checks over the repo's Kujto memory.
/// Exits non-zero when any error-severity issue is found; warnings report
/// without failing so the command stays usable in CI.
struct LintCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "lint",
        abstract: "Lint the repo's memory (AGENTS.md, MEMORY.md, applies_to globs, links)."
    )

    @OptionGroup var global: GlobalOptions

    func run() {
        let emitter = global.makeEmitter()
        let root = KujtoRoot.locate()
        let issues = (try? MemoryLinter.lint(root: root)) ?? []

        if global.json {
            emitter.emit(type: "lint", [
                "root": .string(root.path),
                "issue_count": .int(issues.count),
                "issues": .array(issues.map { issue in
                    .object([
                        "severity": .string(issue.severity.rawValue),
                        "code": .string(issue.code),
                        "file": .string(issue.file),
                        "message": .string(issue.message)
                    ])
                })
            ])
        } else if issues.isEmpty {
            print("Lint clean.")
        } else {
            for issue in issues {
                let marker = issue.severity == .error ? "✗" : "!"
                print("\(marker) [\(issue.severity.rawValue)] \(issue.file): \(issue.message)  (\(issue.code))")
            }
        }

        Foundation.exit(issues.contains(where: { $0.severity == .error }) ? 1 : 0)
    }
}
