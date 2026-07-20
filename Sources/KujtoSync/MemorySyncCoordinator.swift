import Foundation
import KujtoGit

/// The runtime owner of the sync loop. An actor, so every tick is serialized:
/// a push and a pull can never interleave, which is the one hard invariant the
/// design calls for. The UI reads `status`; a watcher (or the app lifecycle)
/// calls `notifyChange()` or `syncNow()`.
///
/// Debounce lives here: a burst of file writes, or a skill touching several
/// memory files, collapses into a single tick. The engine stays pure; the
/// actor holds the timing and the current status.
public actor MemorySyncCoordinator {
    private let engine: MemorySyncEngine
    private let repo: URL
    /// Debounce window in seconds. Kept as `TimeInterval` so the package stays
    /// deployable to macOS 12 (`Duration` is macOS 13+).
    private let debounce: TimeInterval

    /// Current status for the menu-bar glyph.
    public private(set) var status: SyncStatus = .idle
    /// The most recent completed outcome, for surfacing cards.
    public private(set) var lastOutcome: SyncOutcome?

    /// Coalescing token: only the newest scheduled tick survives a debounce
    /// window, so N rapid changes cause one sync, not N.
    private var pendingGeneration = 0

    public init(repo: URL, engine: MemorySyncEngine = MemorySyncEngine(), debounce: TimeInterval = 3) {
        self.repo = repo
        self.engine = engine
        self.debounce = debounce
    }

    /// Run a tick immediately, bypassing the debounce. Used on app launch,
    /// foreground, and network-regained. Returns the outcome for callers that
    /// want it; `status` and `lastOutcome` are updated regardless.
    @discardableResult
    public func syncNow() -> SyncOutcome {
        status = .syncing
        let outcome: SyncOutcome
        do {
            outcome = try engine.tick(in: repo)
        } catch {
            // A true engine error (not offline, not conflict, not secret) means
            // we could not even read the repo. Treat as needs-attention rather
            // than pretend success.
            status = .needsAttention
            let failure = SyncOutcome.pushDeferred
            lastOutcome = failure
            return failure
        }
        lastOutcome = outcome
        status = SyncStatus.from(outcome)
        return outcome
    }

    /// Debounced entry point for the watcher. Schedules a tick after the
    /// debounce window; a newer change during the window replaces the pending
    /// tick so only the last one runs.
    public func notifyChange() {
        pendingGeneration += 1
        let generation = pendingGeneration
        let nanos = UInt64(max(0, debounce) * 1_000_000_000)
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: nanos)
            await self?.fireIfCurrent(generation)
        }
    }

    private func fireIfCurrent(_ generation: Int) {
        guard generation == pendingGeneration else { return }
        _ = syncNow()
    }
}

/// A best-effort folder watcher over `DispatchSource`, watching the memory
/// directory's vnode for writes. This is OS glue for the running app; tests
/// drive the coordinator directly rather than depend on filesystem timing.
///
/// It intentionally reports "something changed" without saying what: the tick
/// re-reads full status anyway, so a coarse signal is enough and cheap.
public final class MemoryFolderWatcher: @unchecked Sendable {
    private let url: URL
    private let onChange: @Sendable () -> Void
    private var source: DispatchSourceFileSystemObject?
    private var descriptor: Int32 = -1
    private let queue = DispatchQueue(label: "dev.kujto.memory-watcher")

    public init(url: URL, onChange: @escaping @Sendable () -> Void) {
        self.url = url
        self.onChange = onChange
    }

    /// Begins watching. Safe to call once; a second call is a no-op.
    public func start() {
        guard source == nil else { return }
        descriptor = open(url.path, O_EVTONLY)
        guard descriptor >= 0 else { return }
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor,
            eventMask: [.write, .rename, .delete, .extend],
            queue: queue
        )
        let onChange = self.onChange
        source.setEventHandler { onChange() }
        source.setCancelHandler { [descriptor] in close(descriptor) }
        self.source = source
        source.resume()
    }

    /// Stops watching and releases the descriptor.
    public func stop() {
        source?.cancel()
        source = nil
        descriptor = -1
    }

    deinit { stop() }
}
