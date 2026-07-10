import ArgumentParser
import Foundation
import KujtoCore

/// `kujto preflight <file>` is the CLI face of the Agent Sandbox: it assembles
/// the pre-flight brief for a file (readiness, missing context, tests, and a
/// paste-ready prompt), weighting the current git diff. With `--sandbox` it
/// also creates a throwaway git worktree so a dry-run touches nothing in the
/// real tree until a human reviews the diff.
struct PreflightCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "preflight",
        abstract: "Assemble an agent pre-flight for a file: readiness, tests, and a ready-to-paste brief."
    )

    @OptionGroup var global: GlobalOptions

    @Argument(help: "Repo-relative path of the file the agent is about to edit.")
    var file: String

    @Option(name: .long, help: "Repo root. Defaults to the current directory.")
    var root: String?

    @Flag(name: .long, help: "Create a throwaway git worktree for a dry-run. Applies nothing.")
    var sandbox: Bool = false

    func run() {
        let emitter = global.makeEmitter()
        runOrExit(emitter) {
            let repo = root.map { URL(fileURLWithPath: $0) }
                ?? URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            let changed = GitDiff.changedFiles(in: repo)
            let pf = try AgentSandbox.preflight(file: file, in: repo, changedFiles: changed)

            var sandboxPath: String?
            if sandbox {
                let wt = try AgentSandbox.makeSandbox(in: repo, name: (file as NSString).lastPathComponent)
                sandboxPath = wt.path.path
            }

            if global.json {
                var fields: [String: NDJSONValue] = [
                    "file": .string(pf.file),
                    "readiness": .string(pf.readiness.rawValue),
                    "readiness_score": .int(pf.readinessScore),
                    "risk_level": .string(pf.risk.level.rawValue),
                    "risk_score": .int(pf.risk.score),
                    "matched_rules": .array(pf.matchedRulePaths.map { .string($0) }),
                    "suggested_tests": .array(pf.suggestedTests.map { .string($0) }),
                    "missing_context": .array(pf.missingContext.map { .string($0) }),
                    "prompt": .string(pf.prompt)
                ]
                if let sandboxPath { fields["sandbox_path"] = .string(sandboxPath) }
                emitter.emit(type: "preflight", fields)
            } else {
                printHuman(pf, sandboxPath: sandboxPath)
            }

            Foundation.exit(pf.readiness == .blocked ? 1 : 0)
        }
    }

    private func printHuman(_ pf: AgentPreflight, sandboxPath: String?) {
        print("Pre-flight for \(pf.file)")
        print("  Readiness: \(pf.readiness.label) (\(pf.readinessScore)/100)")
        print("  Risk: \(pf.risk.level.label) (\(pf.risk.score)/100)")
        if !pf.suggestedTests.isEmpty {
            print("  Tests to run:")
            for test in pf.suggestedTests { print("    - \(test)") }
        }
        if !pf.missingContext.isEmpty {
            print("  Resolve first:")
            for gap in pf.missingContext { print("    - \(gap)") }
        }
        if let sandboxPath {
            print("  Sandbox worktree (dry-run, applies nothing):")
            print("    \(sandboxPath)")
            print("    Remove it with: git worktree remove --force \(sandboxPath)")
        }
        print("")
        print("--- Pre-flight brief ---")
        print(pf.prompt)
    }
}
