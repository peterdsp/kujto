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
            { _, info, _, _, _, _ in
                guard let info else { return }
                let watcher = Unmanaged<RepoWatcher>.fromOpaque(info).takeUnretainedValue()
                watcher.fire()
            },
            &context,
            paths,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.25,
            FSEventStreamCreateFlags(kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagIgnoreSelf)
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

    private func fire() {
        let now = Date()
        guard now.timeIntervalSince(lastFired) > coalesceInterval else { return }
        lastFired = now
        callback?()
    }

    deinit { stop() }
}
