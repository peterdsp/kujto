import SwiftUI
import AppKit
import KujtoCore

/// The Studio shell: a sidebar memory map plus file list, and the "Before You
/// Touch This File" inspector. Standalone home of the app; it also hosts the
/// Xcode Source Editor extension.
struct ContentView: View {
    @EnvironmentObject private var model: StudioModel
    @AppStorage("kujto.hasOnboarded") private var hasOnboarded: Bool = false
    @State private var showWelcome = false

    var body: some View {
        NavigationSplitView {
            Sidebar(model: model, onPick: pickRepo)
                .navigationSplitViewColumnWidth(min: 220, ideal: 240)
        } detail: {
            switch model.destination {
            case .file(let path): Inspector(path: path, model: model)
            case .agents:         AgentsPanel(model: model)
            case .lint:           LintPanel(model: model)
            case .none:           EmptyState(onPick: pickRepo)
            }
        }
        .sheet(isPresented: $showWelcome) {
            WelcomeView(model: model)
        }
        .onAppear {
            model.loadSavedRoot()
            if !hasOnboarded { showWelcome = true }
        }
        .onReceive(NotificationCenter.default.publisher(for: .showKujtoWelcome)) { _ in
            showWelcome = true
        }
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
            List(selection: $model.destination) {
                Section {
                    Label {
                        HStack {
                            Text("Agents").font(.system(size: 13))
                            Spacer()
                            Text("\(model.linkedAgentCount) / \(model.agents.count)")
                                .font(.system(size: 11)).foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "person.2")
                    }
                    .tag(StudioModel.Destination.agents)

                    Label {
                        HStack {
                            Text("Lint").font(.system(size: 13))
                            Spacer()
                            Text("\(model.lintIssues.count)")
                                .font(.system(size: 11))
                                .foregroundStyle(model.lintErrorCount > 0 ? .red : .secondary)
                        }
                    } icon: {
                        Image(systemName: "checkmark.shield")
                    }
                    .tag(StudioModel.Destination.lint)
                }
                Section("Files") {
                    ForEach(model.files) { file in
                        HStack(spacing: 8) {
                            Circle().fill(file.confidence.tint).frame(width: 7, height: 7)
                            Text(file.name).font(.system(size: 13))
                        }
                        .tag(StudioModel.Destination.file(file.id))
                    }
                }
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

                let tests = model.relatedTests(for: path)
                if !tests.isEmpty {
                    TestsToRunCard(tests: tests)
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
        .background(Theme.canvas)
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
                            .background(Color.red.opacity(0.12), in: RoundedRectangle(cornerRadius: Theme.chipRadius))
                    }
                }
            }
            Text(match.rule.path).font(.system(size: 12)).foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.cardRadius))
        .overlay(RoundedRectangle(cornerRadius: Theme.cardRadius).stroke(.black.opacity(0.06)))
    }
}

private struct AgentsPanel: View {
    @ObservedObject var model: StudioModel
    @State private var errorMessage: String?
    @State private var busy = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Agents wired in this repo")
                    .font(.system(size: 12)).foregroundStyle(.secondary)
                HStack(spacing: 10) {
                    Text("Multi-agent sync")
                        .font(.system(size: 18, weight: .medium))
                    Text("\(model.linkedAgentCount) of \(model.agents.count) linked")
                        .font(.system(size: 12))
                        .padding(.vertical, 4).padding(.horizontal, 10)
                        .background(.gray.opacity(0.12), in: Capsule())
                }

                HStack(spacing: 10) {
                    Button {
                        run { model.wireCurrentRepo() }
                    } label: {
                        Label("Wire this repo", systemImage: "link")
                    }
                    .buttonStyle(.borderedProminent).tint(Theme.accent).disabled(busy)

                    Button {
                        run { model.unwireCurrentRepo() }
                    } label: {
                        Label("Unwire", systemImage: "link.badge.minus")
                    }
                    .disabled(busy || model.linkedAgentCount == 0)

                    if busy {
                        ProgressView().scaleEffect(0.7)
                    }
                }

                if let errorMessage {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                        Text(errorMessage).font(.system(size: 12)).foregroundStyle(.secondary)
                    }
                    .padding(10)
                    .background(.orange.opacity(0.10), in: RoundedRectangle(cornerRadius: 8))
                }

                ForEach(model.agents, id: \.agent) { status in
                    AgentRow(status: status)
                }

                Text("Wire also creates .cursorrules and .github/copilot-instructions.md so Cursor and Copilot read the same rules.")
                    .font(.system(size: 12)).foregroundStyle(.tertiary)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Theme.canvas)
    }

    private func run(_ action: @escaping () -> String?) {
        busy = true
        errorMessage = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let result = action()
            busy = false
            errorMessage = result
        }
    }
}

private struct AgentRow: View {
    let status: WireStatus

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon).foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(status.agent.displayName).font(.system(size: 14, weight: .medium))
                Text(status.agent.fileName)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.secondary)
                if let dest = status.linkDestination {
                    Text(dest)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1).truncationMode(.middle)
                }
            }
            Spacer()
            Text(stateLabel)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(stateColor)
                .padding(.vertical, 4).padding(.horizontal, 10)
                .background(stateColor.opacity(0.12), in: Capsule())
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.cardRadius))
        .overlay(RoundedRectangle(cornerRadius: Theme.cardRadius).stroke(.black.opacity(0.06)))
    }

    private var icon: String {
        switch status.agent {
        case .agents:  return "doc.text"
        case .claude:  return "sparkles"
        case .codex:   return "chevron.left.slash.chevron.right"
        case .gemini:  return "diamond"
        case .cursor:  return "arrow.up.and.down.and.arrow.left.and.right"
        case .copilot: return "cursorarrow.rays"
        }
    }

    private var stateLabel: String {
        switch status.state {
        case .linked:     return "linked"
        case .foreign:    return "foreign"
        case .notPresent: return "not present"
        }
    }

    private var stateColor: Color {
        switch status.state {
        case .linked:     return .green
        case .foreign:    return .orange
        case .notPresent: return .gray
        }
    }
}

private struct LintPanel: View {
    @ObservedObject var model: StudioModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Memory health")
                    .font(.system(size: 12)).foregroundStyle(.secondary)
                HStack(spacing: 10) {
                    Text("Lint").font(.system(size: 18, weight: .medium))
                    HealthChip(label: "\(model.lintErrorCount) errors", color: .red)
                    HealthChip(label: "\(model.lintWarningCount) warnings", color: .orange)
                }

                if model.lintIssues.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.seal").foregroundStyle(.green)
                        Text("Lint clean.").font(.system(size: 14))
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.cardRadius))
                    .overlay(RoundedRectangle(cornerRadius: Theme.cardRadius).stroke(.black.opacity(0.06)))
                } else {
                    ForEach(model.lintIssues, id: \.self) { issue in
                        LintRow(issue: issue)
                    }
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Theme.canvas)
    }
}

private struct HealthChip: View {
    let label: String
    let color: Color
    var body: some View {
        Text(label)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(color)
            .padding(.vertical, 4).padding(.horizontal, 10)
            .background(color.opacity(0.12), in: Capsule())
    }
}

private struct LintRow: View {
    let issue: LintIssue
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: issue.severity == .error ? "xmark.octagon" : "exclamationmark.triangle")
                .foregroundStyle(issue.severity == .error ? .red : .orange)
            VStack(alignment: .leading, spacing: 4) {
                Text(issue.message).font(.system(size: 13))
                HStack(spacing: 8) {
                    Text(issue.file).font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary)
                    Text(issue.code).font(.system(size: 11, design: .monospaced)).foregroundStyle(.tertiary)
                }
            }
            Spacer()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.cardRadius))
        .overlay(RoundedRectangle(cornerRadius: Theme.cardRadius).stroke(.black.opacity(0.06)))
    }
}

extension LintIssue: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(file); hasher.combine(code); hasher.combine(message)
    }
}

private struct TestsToRunCard: View {
    let tests: [String]
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "flask").foregroundStyle(.secondary)
                Text("Tests to run").font(.system(size: 14, weight: .medium))
                Text("\(tests.count)").font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 2).padding(.horizontal, 7)
                    .background(.gray.opacity(0.12), in: Capsule())
            }
            ForEach(tests, id: \.self) { path in
                HStack {
                    Text(path).font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button {
                        NSWorkspace.shared.activateFileViewerSelecting([
                            URL(fileURLWithPath: path)
                        ])
                    } label: {
                        Image(systemName: "arrow.up.forward.square").font(.system(size: 11))
                    }
                    .buttonStyle(.plain).foregroundStyle(.tertiary)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.cardRadius))
        .overlay(RoundedRectangle(cornerRadius: Theme.cardRadius).stroke(.black.opacity(0.06)))
    }
}

private struct EmptyState: View {
    let onPick: () -> Void
    var body: some View {
        ZStack {
            Theme.heroGlow.ignoresSafeArea()
            VStack(spacing: 16) {
                Image(systemName: "sparkles")
                    .font(.system(size: 34, weight: .light))
                    .foregroundStyle(Theme.accent)
                Text("Map your repo's memory")
                    .font(.system(size: 22, weight: .medium))
                Text("Drop in a repo and Kujto shows the rules before you touch a file.")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 320)
                Button("Choose repo...", action: onPick)
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.accent)
            }
            .padding(40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
