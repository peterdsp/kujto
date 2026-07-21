import ArgumentParser
import Foundation
import KujtoCore
import KujtoGit
import KujtoSync

/// `kujto sync` runs one memory sync: commit local memory changes, rebase on
/// the remote, and push. A same-line clash or a detected secret is reported
/// rather than resolved (the app surfaces the resolution UI). Deterministic and
/// scriptable, so a cron or a shell hook can keep memory synced headlessly.
struct SyncCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "sync",
        abstract: "Sync the memory repo: commit, rebase, and push."
    )

    @OptionGroup var global: GlobalOptions

    @Argument(help: "Path to the memory repo. Defaults to ~/.kujto/memory-sync.")
    var path: String?

    func run() throws {
        let emitter = global.makeEmitter()
        let repo = path.map { URL(fileURLWithPath: $0) }
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".kujto/memory-sync")

        guard ShellGitClient().isRepository(repo) else {
            if global.json {
                emitter.emit(type: "sync", ["status": .string("no_repo"), "path": .string(repo.path)])
            } else {
                print("No memory repo at \(repo.path). Provision one in Kujto Studio first.")
            }
            Foundation.exit(1)
        }

        let outcome = try MemorySyncEngine().tick(in: repo)
        let (code, label, detail) = Self.describe(outcome)

        if global.json {
            var fields: [String: NDJSONValue] = ["status": .string(code), "message": .string(detail)]
            if case let .conflict(files) = outcome { fields["files"] = .array(files.map { .string($0) }) }
            emitter.emit(type: "sync", fields)
        } else {
            print("\(label) \(detail)")
        }
        // A conflict or a blocked secret is a logical failure the caller should
        // notice; a clean or pushed sync is success.
        Foundation.exit(Self.isFailure(outcome) ? 1 : 0)
    }

    private static func describe(_ outcome: SyncOutcome) -> (code: String, label: String, detail: String) {
        switch outcome {
        case .clean: return ("clean", "✓", "Up to date.")
        case .localOnly: return ("local_only", "✓", "Committed locally (no remote configured).")
        case .pushed: return ("pushed", "✓", "Synced to your remote.")
        case .pushDeferred: return ("push_deferred", "!", "Offline. Committed locally; will retry.")
        case let .conflict(files): return ("conflict", "✗", "Conflict in \(files.joined(separator: ", ")).")
        case let .blockedBySecret(hits):
            let at = hits.first.map { "\($0.file):\($0.line)" } ?? "a file"
            return ("blocked_secret", "✗", "Refused: possible secret in \(at).")
        }
    }

    private static func isFailure(_ outcome: SyncOutcome) -> Bool {
        switch outcome {
        case .conflict, .blockedBySecret: return true
        default: return false
        }
    }
}
