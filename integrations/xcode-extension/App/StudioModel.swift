import Foundation
import SwiftUI
import KujtoCore

/// Drives the Studio shell: scans the chosen repo into a memory map, enumerates
/// its Swift files, and resolves rules and confidence per file. All the logic
/// lives in KujtoCore; this is a thin observable wrapper.
@MainActor
final class StudioModel: ObservableObject {
    struct FileEntry: Identifiable, Hashable {
        let id: String          // repo-relative path
        let name: String
        let confidence: Confidence
    }

    /// What the inspector is showing. Files coexist with "Agents" as a
    /// destination so a sidebar selection can route to either.
    enum Destination: Hashable {
        case agents
        case skills
        case lint
        case file(String)
    }

    @Published private(set) var rootPath: String?
    @Published private(set) var map: MemoryMap?
    @Published private(set) var files: [FileEntry] = []
    @Published private(set) var agents: [WireStatus] = []
    @Published private(set) var lintIssues: [LintIssue] = []
    @Published var destination: Destination?

    /// The current repo risk verdict from the last assessment, and the snapshot
    /// that preceded it, so a dashboard can show "current vs previous" risk.
    /// Populated off the main thread after each scan; nil until the first pass.
    @Published private(set) var risk: RiskScore?
    @Published private(set) var previousRisk: RiskSnapshot?

    /// SwiftData-backed history of repo risk snapshots.
    private let riskLedger = RiskLedgerStore.shared

    /// Parent folder the user pointed Kujto at (e.g. `~/git`). Everything
    /// under it is scanned once for git repos so the user can pick from a
    /// list instead of navigating a file panel.
    @Published private(set) var scanParent: URL?
    @Published private(set) var discoveredRepos: [RepoEntry] = []

    /// Kujto's own skill catalog, loaded from the writable workspace.
    /// Call `reloadSkills()` after editing a skill's markdown.
    @Published private(set) var skills: [SkillEntry] = SkillsCatalog.load()

    /// Refresh the catalog after the user edits a skill in the inline editor.
    func reloadSkills() { skills = SkillsCatalog.load() }

    private var index: RuleIndex?
    private let watcher = RepoWatcher()

    func open(_ url: URL) {
        SharedConfig.saveRoot(url)
        load(url)
        PromptBarBridge.shared.repoRoot = url
    }

    func loadSavedRoot() {
        loadSavedScanParent()
        guard let url = SharedConfig.resolveRoot() else { return }
        defer { url.stopAccessingSecurityScopedResource() }
        load(url)
    }

    /// Set (or replace) the folder we scan for git repos, and refresh the
    /// discovered list. Persists so subsequent launches skip the picker.
    func setScanParent(_ url: URL) {
        SharedConfig.saveScanParent(url)
        scanParent = url
        discoveredRepos = RepoScanner.scan(parent: url)
    }

    /// Re-runs the scan against the current parent. No-op if none is set.
    func rescan() {
        guard let scanParent else { return }
        discoveredRepos = RepoScanner.scan(parent: scanParent)
    }

    private func loadSavedScanParent() {
        guard let url = SharedConfig.resolveScanParent() else { return }
        // Parent stays access-open for the app lifetime so descendant repo
        // URLs remain readable for the initial scan and for the load path.
        scanParent = url
        discoveredRepos = RepoScanner.scan(parent: url)
    }

    func matches(for path: String) -> [RuleMatch] {
        index?.resolve(file: path) ?? []
    }

    func relatedTests(for path: String) -> [String] {
        guard let rootPath else { return [] }
        return RelatedTests.testsFor(file: path, in: URL(fileURLWithPath: rootPath))
    }

    func confidence(for path: String) -> Confidence {
        index?.confidence(forFile: path) ?? .safe
    }

    /// Count of agents currently linked to this Kujto root. Drives the "X / Y"
    /// hint shown next to the sidebar's Agents row.
    var linkedAgentCount: Int {
        agents.filter { $0.state == .linked }.count
    }

    /// Wire Kujto memory into the currently loaded repo. Uses `KujtoLocator`
    /// to find the Kujto installation. Idempotent: existing files are left
    /// alone by `WireService.linkOrCopy`. Returns nil on success, or a short
    /// error message the UI can surface.
    func wireCurrentRepo() -> String? {
        guard let target = rootPath.map({ URL(fileURLWithPath: $0) }) else {
            return "Choose a repo first."
        }
        guard let kujtoRoot = KujtoLocator.locate() else {
            return "Kujto installation not found. Set KUJTO_ROOT or clone Kujto into ~/kujto."
        }
        do {
            let emitter = EventEmitter(mode: .human)
            let service = WireService(root: kujtoRoot, emitter: emitter)
            try service.wire(WireService.Options(target: target))
            refreshAgents()
            return nil
        } catch let error as KujtoError {
            return error.message.value
        } catch {
            return error.localizedDescription
        }
    }

    /// Undo `wireCurrentRepo`. Only removes symlinks; foreign files stay.
    func unwireCurrentRepo() -> String? {
        guard let target = rootPath.map({ URL(fileURLWithPath: $0) }) else {
            return "Choose a repo first."
        }
        guard let kujtoRoot = KujtoLocator.locate() else {
            return "Kujto installation not found."
        }
        do {
            let emitter = EventEmitter(mode: .human)
            let service = WireService(root: kujtoRoot, emitter: emitter)
            try service.unwire(at: target)
            refreshAgents()
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    func refreshAgents() {
        guard let root = rootPath.map({ URL(fileURLWithPath: $0) }) else { return }
        agents = AgentExport.status(target: root, root: root)
    }

    private func load(_ root: URL) {
        rootPath = root.path
        let idx = try? RuleIndex.load(root: root)
        index = idx
        map = try? MemoryMapScanner.scan(root: root)
        files = Self.swiftFiles(under: root)
            .map { rel in
                FileEntry(
                    id: rel,
                    name: (rel as NSString).lastPathComponent,
                    confidence: idx?.confidence(forFile: rel) ?? .safe
                )
            }
            .sorted { lhs, rhs in
                lhs.confidence.rank != rhs.confidence.rank
                    ? lhs.confidence.rank > rhs.confidence.rank
                    : lhs.name < rhs.name
            }
        agents = AgentExport.status(target: root, root: root)
        lintIssues = (try? MemoryLinter.lint(root: root)) ?? []
        destination = files.first.map { .file($0.id) } ?? .agents
        refreshRisk(root: root)
        watcher.start(at: root.path) { [weak self] in
            self?.reloadInPlace()
        }
    }

    /// Called by the FSEvents watcher when the repo changes on disk. Refreshes
    /// the memory map, rules, and lint output without disturbing the current
    /// sidebar destination or selection.
    private func reloadInPlace() {
        guard let rootPath else { return }
        let root = URL(fileURLWithPath: rootPath)
        let idx = try? RuleIndex.load(root: root)
        index = idx
        map = try? MemoryMapScanner.scan(root: root)
        agents = AgentExport.status(target: root, root: root)
        lintIssues = (try? MemoryLinter.lint(root: root)) ?? []
        refreshRisk(root: root)
    }

    /// Assesses repo risk off the main thread, records a snapshot, and
    /// publishes the current verdict plus the previous snapshot. Deterministic
    /// and local; no model calls. Failures are swallowed so a scoring hiccup
    /// never disturbs the rest of the shell.
    private func refreshRisk(root: URL) {
        Task { [weak self] in
            let assessment = await Task.detached(priority: .utility) {
                try? RiskScorer.assess(root: root)
            }.value
            guard let self, let assessment else { return }
            // Capture the prior latest before recording the new snapshot.
            self.previousRisk = self.riskLedger.latestSnapshot(forRepo: root.path)
            self.riskLedger.record(RiskSnapshot(assessment, repoPath: root.path))
            self.risk = assessment.verdict
        }
    }

    var lintErrorCount: Int { lintIssues.filter { $0.severity == .error }.count }
    var lintWarningCount: Int { lintIssues.filter { $0.severity == .warning }.count }

    private static func swiftFiles(under root: URL) -> [String] {
        let fm = FileManager.default
        guard let walker = fm.enumerator(at: root, includingPropertiesForKeys: nil) else { return [] }
        var out: [String] = []
        for case let url as URL in walker where url.pathExtension == "swift" {
            let path = url.path
            if path.contains("/.build/") || path.contains("/DerivedData/") { continue }
            let rel = path.hasPrefix(root.path + "/") ? String(path.dropFirst(root.path.count + 1)) : path
            out.append(rel)
            if out.count >= 1000 { break }
        }
        return out
    }
}

extension Confidence {
    /// Sidebar dot and badge tint.
    var tint: Color {
        switch self {
        case .safe: return .green
        case .needsContext: return .orange
        case .dangerZone: return .red
        }
    }

    /// Sort weight so danger files float to the top of the sidebar.
    var rank: Int {
        switch self {
        case .dangerZone: return 2
        case .needsContext: return 1
        case .safe: return 0
        }
    }
}
