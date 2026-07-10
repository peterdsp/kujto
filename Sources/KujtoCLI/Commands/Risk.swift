import ArgumentParser
import Foundation
import KujtoCore

/// `kujto risk` is the CLI face of Predictive Governance: it scores the repo's
/// governance risk, weighting files that are in the current git diff so a risky
/// edit is flagged before it is committed. Emits JSON for the editor
/// integrations and exits non-zero when the verdict is Blocked, so it can gate
/// a pre-commit hook or CI step.
struct RiskCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "risk",
        abstract: "Score repo governance risk, weighting files in the current diff."
    )

    @OptionGroup var global: GlobalOptions

    @Option(name: .long, help: "Repo root to assess. Defaults to the current directory.")
    var root: String?

    @Flag(name: .long, help: "Ignore the git diff and score every rule-matched file evenly.")
    var all: Bool = false

    func run() {
        let emitter = global.makeEmitter()
        runOrExit(emitter) {
            let repo = root.map { URL(fileURLWithPath: $0) }
                ?? URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            let changed = all ? [] : GitDiff.changedFiles(in: repo)
            let assessment = try RiskScorer.assess(root: repo, changedFiles: changed)
            let verdict = assessment.verdict

            if global.json {
                emitter.emit(type: "risk", [
                    "root": .string(repo.path),
                    "level": .string(verdict.level.rawValue),
                    "score": .int(verdict.score),
                    "headline": .string(verdict.headline),
                    "action": .string(verdict.action.rawValue),
                    "changed": .array(changed.sorted().map { .string($0) }),
                    "files": .array(assessment.files.map { fileScore(for: $0, changed: changed) })
                ])
            } else {
                printHuman(assessment: assessment, changed: changed)
            }

            // Blocked is the only hard stop; everything else reports and passes.
            Foundation.exit(verdict.level == .blocked ? 1 : 0)
        }
    }

    private func fileScore(for file: FileScore, changed: Set<String>) -> NDJSONValue {
        .object([
            "file": .string(file.path),
            "level": .string(file.score.level.rawValue),
            "score": .int(file.score.score),
            "headline": .string(file.score.headline),
            "action": .string(file.score.action.rawValue),
            "dirty": .bool(changed.contains(file.path)),
            "causes": .array(file.score.causes.prefix(3).map { cause in
                .object([
                    "title": .string(cause.title),
                    "detail": .string(cause.detail),
                    "weight": .int(cause.weight)
                ])
            })
        ])
    }

    private func printHuman(assessment: RepoAssessment, changed: Set<String>) {
        let verdict = assessment.verdict
        print("Risk: \(verdict.level.label) (\(verdict.score)/100)")
        print("  \(verdict.headline)")
        print("  Next: \(verdict.action.label)")
        if !changed.isEmpty {
            print("  \(changed.count) file(s) in the current diff.")
        }
        let flagged = assessment.files.filter { $0.score.level > .safe }
        guard !flagged.isEmpty else { return }
        print("")
        for file in flagged.prefix(10) {
            let dirty = changed.contains(file.path) ? " *" : ""
            print("  [\(file.score.level.label)] \(file.path)\(dirty)")
            print("      \(file.score.headline)")
        }
        if !changed.isEmpty {
            print("")
            print("  * = in the current diff")
        }
    }
}
