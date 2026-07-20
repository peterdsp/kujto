import Foundation
import KujtoGit
import KujtoCore

/// The heart of the invisible sync loop, as a pure orchestration over a
/// `GitClient` and the `SecretScanner`. One `tick` performs the whole design
/// sequence: stage, secret-guard, commit, pull --rebase, push, classified into
/// a `SyncOutcome`. It never throws for the ordinary failure modes (offline, a
/// same-line clash, a secret): those are outcomes, not errors, so the caller
/// treats them as states to surface rather than crashes to handle.
///
/// It is deliberately synchronous and side-effect-contained: give it a repo,
/// it returns what happened. `MemorySyncCoordinator` owns the actor, the
/// debounce, and the watcher; the engine owns the decision.
public struct MemorySyncEngine: Sendable {
    private let client: GitClient
    private let scanner: SecretScanner

    public init(client: GitClient = ShellGitClient(), scanner: SecretScanner = SecretScanner()) {
        self.client = client
        self.scanner = scanner
    }

    /// Runs one sync tick against `repo`.
    public func tick(in repo: URL) throws -> SyncOutcome {
        let status = try client.status(in: repo)

        // 1. Commit local changes, gated by the secret guard.
        var committed = false
        if !status.isClean {
            try client.stage([], in: repo)
            let staged = try client.diff(in: repo, path: nil, staged: true)
            let hits = scanner.scanDiff(staged)
            if !hits.isEmpty {
                // Leave the repo dirty: unstage so a later tick re-evaluates
                // once the user removes the secret. Nothing is committed.
                try? client.unstage([], in: repo)
                return .blockedBySecret(hits)
            }
            let message = CommitMessageBuilder.message(for: status.changes)
            _ = try client.commit(message: message, in: repo)
            committed = true
        }

        // 2. No remote configured: this is a local-only checkout. We are done.
        let afterCommit = try client.status(in: repo)
        guard afterCommit.upstream != nil else {
            return committed ? .localOnly : .clean
        }

        // 3. Pull with rebase. Reaching the remote can fail (offline); a real
        //    same-line clash returns .conflicted rather than throwing.
        do {
            let rebase = try client.pullRebase(in: repo)
            if case let .conflicted(files) = rebase {
                return .conflict(files)
            }
        } catch {
            // Offline. Anything committed is safe locally and will retry.
            return committed ? .pushDeferred : .clean
        }

        // 4. Push. Because we rebased first, a non-fast-forward here is only a
        //    rare race: another machine pushed between our rebase and push.
        //    Rebase once more and retry; if the remote is now unreachable, the
        //    local commit is still safe.
        do {
            try client.push(in: repo)
            return committed ? .pushed : .clean
        } catch {
            let retry: RebaseOutcome
            do {
                retry = try client.pullRebase(in: repo)
            } catch {
                return committed ? .pushDeferred : .clean
            }
            if case let .conflicted(files) = retry {
                return .conflict(files)
            }
            do {
                try client.push(in: repo)
                return committed ? .pushed : .clean
            } catch {
                return .pushDeferred
            }
        }
    }
}
