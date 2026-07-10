import ArgumentParser
import Foundation
import KujtoCore

/// `kujto sign-proposals` produces signed, portable rule proposals from the
/// deterministic proposal engine, so a teammate can receive them with
/// verifiable provenance. It signs; it never installs anything.
struct SignProposalsCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "sign-proposals",
        abstract: "Sign deterministic rule proposals for sharing (verifiable provenance; never installs)."
    )

    @OptionGroup var global: GlobalOptions

    @Option(name: .long, help: "Repo root. Defaults to the current directory.")
    var root: String?

    @Option(name: .long, help: "Signing key path. Defaults to ~/.kujto/identity.key.")
    var key: String?

    @Option(name: .long, help: "Author label recorded as provenance.")
    var author: String = NSFullUserName()

    @Option(name: .long, help: "Write signed proposals (.json) to this directory.")
    var out: String?

    func run() {
        let emitter = global.makeEmitter()
        runOrExit(emitter) {
            let repo = root.map { URL(fileURLWithPath: $0) }
                ?? URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            let identity = try LocalIdentity.loadOrCreate(at: keyURL())
            let proposals = try RuleProposalEngine.propose(in: repo)

            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601

            var signed: [SignedProposal] = []
            for proposal in proposals {
                let portable = PortableProposal(proposal, author: author, repoName: repo.lastPathComponent)
                signed.append(try ProposalSigner.sign(portable, with: identity.privateKey))
            }

            var written: [String] = []
            if let out, !signed.isEmpty {
                let dir = URL(fileURLWithPath: out)
                try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                for item in signed {
                    let dest = dir.appendingPathComponent("proposal-\(item.proposal.id.uuidString).json")
                    try encoder.encode(item).write(to: dest, options: .atomic)
                    written.append(dest.path)
                }
            }

            if global.json {
                emitter.emit(type: "sign_proposals", [
                    "signer": .string(identity.fingerprint),
                    "count": .int(signed.count),
                    "written": .array(written.map { .string($0) })
                ])
            } else {
                print("Signer fingerprint: \(identity.fingerprint)")
                print("Signed \(signed.count) proposal(s). Nothing installed.")
                for path in written { print("  wrote \(path)") }
                if signed.isEmpty { print("No proposals to sign; every role group is covered.") }
            }
            Foundation.exit(0)
        }
    }

    private func keyURL() -> URL {
        if let key { return URL(fileURLWithPath: key) }
        return FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".kujto/identity.key")
    }
}

/// `kujto verify-proposal <file>` verifies a received signed proposal and prints
/// its provenance. It explicitly does NOT install the rule: adoption is always a
/// human step, per the P2P guardrail.
struct VerifyProposalCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "verify-proposal",
        abstract: "Verify a received signed proposal and show its provenance. Never installs it."
    )

    @OptionGroup var global: GlobalOptions

    @Argument(help: "Path to a signed proposal JSON file.")
    var file: String

    func run() {
        let emitter = global.makeEmitter()
        runOrExit(emitter) {
            let data = try Data(contentsOf: URL(fileURLWithPath: file))
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let signed = try decoder.decode(SignedProposal.self, from: data)
            let valid = ProposalSigner.verify(signed)
            let p = signed.proposal

            if global.json {
                emitter.emit(type: "verify_proposal", [
                    "valid": .bool(valid),
                    "signer": .string(signed.signerFingerprint),
                    "title": .string(p.title),
                    "applies_to": .array(p.appliesTo.map { .string($0) }),
                    "author": .string(p.author),
                    "repo": .string(p.repoName),
                    "installed": .bool(false)
                ])
            } else {
                print(valid ? "Signature: VALID" : "Signature: INVALID (do not trust)")
                print("  Signer fingerprint: \(signed.signerFingerprint)")
                print("  Title: \(p.title)")
                print("  Globs: \(p.appliesTo.joined(separator: ", "))")
                print("  From: \(p.author) · repo \(p.repoName)")
                print("")
                print("Not installed. Review the draft and move it into memory/ yourself to adopt.")
            }
            // Non-zero when the signature does not verify, so a pipeline can gate.
            Foundation.exit(valid ? 0 : 1)
        }
    }
}
