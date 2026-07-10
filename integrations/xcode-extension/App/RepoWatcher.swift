import Foundation

/// Watches a repo directory with FSEvents and calls a coalesced callback when
/// anything under it changes. Used by StudioModel to auto-refresh the memory
/// map + rule index when the user edits files outside the app (Xcode, git
/// pull, another editor). Coalescing avoids reloading on every keystroke.
final class RepoWatcher {
    private var stream: FSEventStreamRef?
    private var callback: (() -> Void)?
    private var lastFired: Date = .distantPast

    /// Debounce window for the callback: fires at most once per 300 ms.
    private let coalesceInterval: TimeInterval = 0.3

    func start(at path: String, onChange: @escaping () -> Void) {
        stop()
        callback = onChange
        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil, release: nil, copyDescription: nil
        )
        let paths = [path] as CFArray
        let stream = FSEventStreamCreate(
            kCFAllocatorDefault,
            { _, info, _, eventPaths, _, _ in
                guard let info else { return }
                let watcher = Unmanaged<RepoWatcher>.fromOpaque(info).takeUnretainedValue()
                let changed = unsafeBitCast(eventPaths, to: NSArray.self) as? [String] ?? []
                watcher.fire(paths: changed)
            },
            &context,
            paths,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.25,
            // UseCFTypes so eventPaths arrives as an NSArray of Strings we can
            // inspect and filter (see fire(paths:)).
            FSEventStreamCreateFlags(
                kFSEventStreamCreateFlagFileEvents
                | kFSEventStreamCreateFlagIgnoreSelf
                | kFSEventStreamCreateFlagUseCFTypes
            )
        )
        guard let stream else { return }
        FSEventStreamSetDispatchQueue(stream, DispatchQueue.main)
        FSEventStreamStart(stream)
        self.stream = stream
    }

    func stop() {
        if let stream {
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
        }
        stream = nil
        callback = nil
    }

    /// Directory fragments whose changes must never trigger a reload. This is
    /// the fix for a CPU-pinning feedback loop: our own reload runs `git status`
    /// and `git log`, git touches files under `.git/`, FSEvents reports it, we
    /// reload, we run git again... forever. `IgnoreSelf` does not help because
    /// git runs as a separate process. Vendored/build trees are ignored for the
    /// same churn reasons.
    private static let ignoredFragments = [
        "/.git/", "/.build/", "/DerivedData/", "/node_modules/",
        "/Pods/", "/.swiftpm/", "/.kujto/"
    ]

    private func fire(paths: [String]) {
        // Fire only when a path we care about changed. If every changed path is
        // inside an ignored tree (typically git internals from our own reads),
        // do nothing, breaking the loop.
        let relevant = paths.contains { path in
            !Self.ignoredFragments.contains { path.contains($0) }
        }
        guard relevant else { return }

        let now = Date()
        guard now.timeIntervalSince(lastFired) > coalesceInterval else { return }
        lastFired = now
        callback?()
    }

    deinit { stop() }
}
