import SwiftUI
import AppKit
import KujtoCore

/// The Studio shell: a sidebar memory map plus file list, and the "Before You
/// Touch This File" inspector. Standalone home of the app; it also hosts the
/// Xcode Source Editor extension.
struct ContentView: View {
    @StateObject private var model = StudioModel()

    var body: some View {
        NavigationSplitView {
            Sidebar(model: model, onPick: pickRepo)
                .navigationSplitViewColumnWidth(min: 220, ideal: 240)
        } detail: {
            if let path = model.selection {
                Inspector(path: path, model: model)
            } else {
                EmptyState(onPick: pickRepo)
            }
        }
        .onAppear { model.loadSavedRoot() }
    }

    private func pickRepo() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            model.open(url)
        }
    }
}

private struct Sidebar: View {
    @ObservedObject var model: StudioModel
    let onPick: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let map = model.map {
                HStack(spacing: 8) {
                    Metric(value: map.scopedRules.count, label: "scoped")
                    Metric(value: map.baseRules.count, label: "base")
                    Metric(value: map.skillCount, label: "skills")
                }
                .padding(12)
            }
            Divider()
            List(model.files, selection: $model.selection) { file in
                HStack(spacing: 8) {
                    Circle().fill(file.confidence.tint).frame(width: 7, height: 7)
                    Text(file.name).font(.system(size: 13))
                }
                .tag(file.id)
            }
            .listStyle(.sidebar)
        }
        .toolbar {
            ToolbarItem {
                Button(action: onPick) { Image(systemName: "folder") }
                    .help("Choose repo")
            }
        }
    }
}

private struct Metric: View {
    let value: Int
    let label: String
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(value)").font(.system(size: 18, weight: .medium))
            Text(label).font(.system(size: 11)).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8).padding(.horizontal, 10)
        .background(Color(.controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct Inspector: View {
    let path: String
    @ObservedObject var model: StudioModel

    var body: some View {
        let matches = model.matches(for: path)
        let confidence = model.confidence(for: path)

        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Before you touch this file")
                    .font(.system(size: 12)).foregroundStyle(.secondary)

                HStack(spacing: 10) {
                    Text((path as NSString).lastPathComponent)
                        .font(.system(size: 18, weight: .medium, design: .monospaced))
                    ConfidenceBadge(confidence: confidence)
                }

                if matches.isEmpty {
                    Text("No file-scoped rules match. Base memory still applies.")
                        .font(.system(size: 13)).foregroundStyle(.secondary)
                } else {
                    ForEach(matches, id: \.rule.path) { match in
                        RuleCard(match: match)
                    }
                }

                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(agentContext(matches), forType: .string)
                } label: {
                    Label("Inject agent context", systemImage: "wand.and.stars")
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func agentContext(_ matches: [RuleMatch]) -> String {
        var lines = ["Rules for \(path):"]
        for match in matches {
            lines.append("- \(match.rule.title) (\(match.rule.path))")
        }
        return lines.joined(separator: "\n")
    }
}

private struct ConfidenceBadge: View {
    let confidence: Confidence
    var body: some View {
        Text(confidence.label)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(confidence.tint)
            .padding(.vertical, 4).padding(.horizontal, 10)
            .background(confidence.tint.opacity(0.12), in: Capsule())
    }
}

private struct RuleCard: View {
    let match: RuleMatch
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "shield.lefthalf.filled").foregroundStyle(.secondary)
                Text(match.rule.title).font(.system(size: 14, weight: .medium))
                Text(match.glob).font(.system(size: 11, design: .monospaced)).foregroundStyle(.tertiary)
            }
            if !match.rule.risk.isEmpty {
                HStack(spacing: 6) {
                    Text("risk").font(.system(size: 11)).foregroundStyle(.secondary)
                    ForEach(match.rule.risk, id: \.self) { tag in
                        Text(tag)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.red)
                            .padding(.vertical, 2).padding(.horizontal, 8)
                            .background(Color.red.opacity(0.12), in: RoundedRectangle(cornerRadius: 6))
                    }
                }
            }
            Text(match.rule.path).font(.system(size: 12)).foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct EmptyState: View {
    let onPick: () -> Void
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "feather").font(.system(size: 32)).foregroundStyle(.secondary)
            Text("Pick a repo to map its memory.").foregroundStyle(.secondary)
            Button("Choose repo...", action: onPick)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
