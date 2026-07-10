import ArgumentParser
import Foundation
import KujtoCore

/// `kujto propose` is the CLI face of Generative Memory: it deterministically
/// suggests scoped rules for file groups that have none, and drafts reviewable
/// memory files. It never writes into memory/ on its own. With `--out <dir>` it
/// writes the drafts to a staging directory the human then reviews and moves.
struct ProposeCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "propose",
        abstract: "Propose scoped rules for uncovered file groups. Drafts only; never writes memory."
    )

    @OptionGroup var global: GlobalOptions

    @Option(name: .long, help: "Repo root. Defaults to the current directory.")
    var root: String?

    @Option(name: .long, help: "Minimum files in a role group before it is proposed.")
    var minFiles: Int = 3

    @Option(name: .long, help: "Write drafts to this staging directory (never memory/). Off by default.")
    var out: String?

    func run() {
        let emitter = global.makeEmitter()
        runOrExit(emitter) {
            let repo = root.map { URL(fileURLWithPath: $0) }
                ?? URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            let proposals = try RuleProposalEngine.propose(in: repo, minFiles: minFiles)

            var written: [String] = []
            if let out, !proposals.isEmpty {
                let dir = URL(fileURLWithPath: out)
                try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                for proposal in proposals {
                    let name = (proposal.suggestedPath as NSString).lastPathComponent
                    let dest = dir.appendingPathComponent(name)
                    try proposal.draftMarkdown.write(to: dest, atomically: true, encoding: .utf8)
                    written.append(dest.path)
                }
            }

            if global.json {
                emitter.emit(type: "propose", [
                    "root": .string(repo.path),
                    "proposal_count": .int(proposals.count),
                    "written": .array(written.map { .string($0) }),
                    "proposals": .array(proposals.map { proposal in
                        .object([
                            "title": .string(proposal.title),
                            "applies_to": .array(proposal.appliesTo.map { .string($0) }),
                            "rationale": .string(proposal.rationale),
                            "suggested_path": .string(proposal.suggestedPath),
                            "affected_files": .array(proposal.affectedFiles.map { .string($0) }),
                            "draft": .string(proposal.draftMarkdown)
                        ])
                    })
                ])
            } else {
                printHuman(proposals: proposals, written: written)
            }

            Foundation.exit(0)
        }
    }

    private func printHuman(proposals: [RuleProposal], written: [String]) {
        if proposals.isEmpty {
            print("No rule proposals. Every role group is already covered by a scoped rule.")
            return
        }
        print("\(proposals.count) rule proposal(s). Review before adopting; Kujto wrote nothing into memory/.")
        for proposal in proposals {
            print("")
            print("  \(proposal.title)")
            print("    globs: \(proposal.appliesTo.joined(separator: ", "))")
            print("    \(proposal.rationale)")
            print("    suggested: \(proposal.suggestedPath)")
        }
        if !written.isEmpty {
            print("")
            print("Wrote \(written.count) draft(s) to the staging directory:")
            for path in written { print("  \(path)") }
            print("Move a draft into memory/ to adopt it.")
        }
    }
}
