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
        case file(String)
    }

    @Published private(set) var rootPath: String?
    @Published private(set) var map: MemoryMap?
    @Published private(set) var files: [FileEntry] = []
    @Published private(set) var agents: [WireStatus] = []
    @Published var destination: Destination?

    private var index: RuleIndex?

    func open(_ url: URL) {
        SharedConfig.saveRoot(url)
        load(url)
    }

    func loadSavedRoot() {
        guard let url = SharedConfig.resolveRoot() else { return }
        defer { url.stopAccessingSecurityScopedResource() }
        load(url)
    }

    func matches(for path: String) -> [RuleMatch] {
        index?.resolve(file: path) ?? []
    }

    func confidence(for path: String) -> Confidence {
        index?.confidence(forFile: path) ?? .safe
    }

    /// Count of agents currently linked to this Kujto root. Drives the "X / Y"
    /// hint shown next to the sidebar's Agents row.
    var linkedAgentCount: Int {
        agents.filter { $0.state == .linked }.count
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
        destination = files.first.map { .file($0.id) } ?? .agents
    }

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
