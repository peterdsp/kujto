import Foundation
import SwiftUI
import KujtoGit
import KujtoSync

/// Runs the invisible memory sync loop for the app. It owns the tested
/// `MemorySyncCoordinator` and a folder watcher over the local memory checkout,
/// coalescing file changes into debounced syncs and reflecting status for the
/// menu-bar glyph and the settings tab.
///
/// The sync engine itself (commit, rebase, push, secret guard, conflict
/// handling) lives in KujtoSync and is fully tested; this is the app-side glue
/// that starts it and surfaces its state.
@MainActor
final class MemorySyncService: ObservableObject {
    @Published private(set) var status: SyncStatus = .idle
    @Published private(set) var lastMessage: String?

    static let shared = MemorySyncService()

    private var coordinator: MemorySyncCoordinator?
    private var watcher: MemoryFolderWatcher?

    /// Where the synced memory repo lives once provisioned and cloned.
    var memoryDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".kujto/memory-sync")
    }

    /// True when a memory checkout exists to sync.
    var isReady: Bool {
        ShellGitClient().isRepository(memoryDirectory)
    }

    var isRunning: Bool { coordinator != nil }

    /// Starts watching and syncing the memory checkout. A no-op when it is not
    /// yet cloned or already running.
    func start() {
        guard coordinator == nil else { return }
        let dir = memoryDirectory
        guard ShellGitClient().isRepository(dir) else {
            status = .idle
            lastMessage = "No memory repo yet. Connect a provider in Memory Sync."
            return
        }
        let coordinator = MemorySyncCoordinator(repo: dir)
        self.coordinator = coordinator
        let watcher = MemoryFolderWatcher(url: dir) {
            Task { await coordinator.notifyChange() }
        }
        watcher.start()
        self.watcher = watcher
        Task { await syncNow() }
    }

    /// Adopts a freshly provisioned repo: clones it to the memory directory if
    /// it is not already there, then starts the loop. The clone shells to `git`
    /// and uses the system credential helper (the design's bring-your-own-cred
    /// path); if credentials are not available the loop simply stays idle until
    /// the user configures them, and nothing is lost.
    func adoptRepo(cloneURL: String) {
        let dir = memoryDirectory
        let client = ShellGitClient()
        if client.isRepository(dir) {
            start()
            return
        }
        lastMessage = "Cloning your memory repo..."
        Task.detached {
            do {
                try client.clone(cloneURL, to: dir)
                await MainActor.run { self.start() }
            } catch {
                await MainActor.run {
                    self.status = .offline
                    self.lastMessage = "Could not clone yet. Check your git credentials, then Start."
                }
            }
        }
    }

    /// Forces an immediate sync (app launch, foreground, manual refresh).
    func syncNow() async {
        guard let coordinator else { return }
        let outcome = await coordinator.syncNow()
        status = await coordinator.status
        lastMessage = Self.describe(outcome)
    }

    /// Stops watching and releases the loop.
    func stop() {
        watcher?.stop()
        watcher = nil
        coordinator = nil
        status = .idle
    }

    private static func describe(_ outcome: SyncOutcome) -> String {
        switch outcome {
        case .clean: return "Up to date."
        case .localOnly: return "Committed locally (no remote configured)."
        case .pushed: return "Synced to your remote."
        case .pushDeferred: return "Offline. Committed locally; will retry."
        case let .conflict(files): return "Conflict in \(files.joined(separator: ", ")). Resolve to continue."
        case let .blockedBySecret(hits):
            let where_ = hits.first.map { "\($0.file):\($0.line)" } ?? "a file"
            return "Refused to sync: possible secret in \(where_)."
        }
    }
}
