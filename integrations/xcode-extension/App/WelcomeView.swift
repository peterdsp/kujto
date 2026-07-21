import SwiftUI
import AppKit
import KujtoCore
import KujtoAuth

/// First-run onboarding wizard. Four steps: welcome, pick a repo, verify
/// installed surfaces, done. Smooth spring transitions between steps, no
/// forced navigation; the user can dismiss the sheet at any time.
///
/// Also reused from Settings so the flow can be re-run any time.
struct WelcomeView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var model: StudioModel

    @State private var step: Step = .hello
    @State private var status: [InstallStatus.Component] = []
    /// Increments on each Refresh tap. Drives a one-shot bounce on the
    /// refresh arrow via `.symbolEffect(.bounce, value:)`.
    @State private var refreshTick: Int = 0

    enum Step: Int, CaseIterable {
        case hello, pickRepo, wire, memory, done
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.4)

            ZStack {
                Theme.heroGlow.opacity(step == .hello || step == .done ? 1 : 0)
                    .animation(.easeInOut(duration: 0.6), value: step)

                Group {
                    switch step {
                    case .hello:     helloStep
                    case .pickRepo:  pickRepoStep
                    case .wire:      wireStep
                    case .memory:    memoryStep
                    case .done:      doneStep
                    }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
                .id(step)
            }
            .animation(.spring(response: 0.5, dampingFraction: 0.85), value: step)
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider().opacity(0.4)
            footer
        }
        .frame(minWidth: 620, minHeight: 460)
        .background(Theme.canvas)
        .onAppear { status = InstallStatus.snapshot() }
    }

    // MARK: - Header, footer

    private var header: some View {
        HStack(spacing: 10) {
            Circle().fill(Theme.accent).frame(width: 6, height: 6)
            Text("Getting started with Kujto Studio")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
            Spacer()
            StepDots(current: step)
        }
        .padding(.horizontal, 20).padding(.vertical, 14)
    }

    private var footer: some View {
        HStack {
            if step != .hello {
                Button("Back") { withAnimation { step = previous(step) } }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if step == .done {
                Button("Finish") { finish() }
                    .buttonStyle(.borderedProminent).tint(Theme.accent)
            } else {
                Button(nextLabel) { advance() }
                    .buttonStyle(.borderedProminent).tint(Theme.accent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canAdvance)
            }
        }
        .padding(.horizontal, 20).padding(.vertical, 14)
    }

    private var nextLabel: String {
        switch step {
        case .hello: return "Get started"
        case .pickRepo: return model.rootPath == nil ? "Choose repo..." : "Continue"
        case .wire: return "Continue"
        case .memory: return "Continue"
        case .done: return "Finish"
        }
    }

    private var canAdvance: Bool {
        switch step {
        case .pickRepo: return model.rootPath != nil
        default: return true
        }
    }

    private func advance() {
        if step == .pickRepo && model.rootPath == nil { pickRepo(); return }
        withAnimation { step = next(step) }
        if step == .wire { status = InstallStatus.snapshot() }
    }

    private func finish() {
        UserDefaults.standard.set(true, forKey: "kujto.hasOnboarded")
        dismiss()
    }

    private func next(_ s: Step) -> Step { Step(rawValue: s.rawValue + 1) ?? s }
    private func previous(_ s: Step) -> Step { Step(rawValue: s.rawValue - 1) ?? s }

    // MARK: - Steps

    private var helloStep: some View {
        VStack(spacing: 20) {
            Image(systemName: "sparkles")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(Theme.accent)
            Text("Kujto Studio")
                .font(.system(size: 30, weight: .semibold))
            Text("The local memory layer that keeps AI agents and developers from breaking your codebase rules.")
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)
        }
        .padding(40)
    }

    private var pickRepoStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            StepTitle(icon: "folder", title: "Point Kujto at a repo",
                      subtitle: "Kujto reads memory from AGENTS.md, memory/, and the file layout. Everything stays on your machine.")

            ScanParentCard(
                parent: model.scanParent,
                repoCount: model.discoveredRepos.count,
                onChoose: pickScanParent,
                onRescan: { model.rescan() }
            )

            if model.scanParent != nil {
                DiscoveredReposList(
                    repos: model.discoveredRepos,
                    selectedPath: model.rootPath,
                    onSelect: { model.open($0) }
                )
            }

            Button(action: pickRepo) {
                Label("Or point at a single repo directly...", systemImage: "folder.badge.plus")
                    .font(.system(size: 12))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)

            Spacer(minLength: 0)
        }
        .padding(30)
    }

    private func pickScanParent() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Scan"
        panel.message = "Pick the folder where you keep your projects (e.g. ~/git). Kujto scans it for repos."
        if panel.runModal() == .OK, let url = panel.url {
            model.setScanParent(url)
        }
    }

    private var wireStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            StepTitle(icon: "puzzlepiece.extension", title: "Where Kujto lives",
                      subtitle: "One engine, four surfaces. Each is optional. Install the ones you want; skip the rest and Kujto Studio still works on its own.")

            VStack {
                if let root = model.rootPath {
                    RepoWireBadge(root: URL(fileURLWithPath: root))
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .top)),
                            removal: .opacity
                        ))
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: model.rootPath)

            ScrollView {
                VStack(spacing: 10) {
                    ForEach(status) { component in
                        StatusRow(component: component)
                            .transition(.opacity.combined(with: .move(edge: .leading)))
                    }
                }
                .padding(.vertical, 2)
            }
            .frame(maxHeight: .infinity)
            .animation(.spring(response: 0.4), value: status)

            HStack {
                Button {
                    refreshTick &+= 1
                    withAnimation { status = InstallStatus.snapshot() }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.clockwise")
                            .symbolEffect(.bounce, value: refreshTick)
                        Text("Refresh status")
                    }
                }
                .buttonStyle(.plain).foregroundStyle(.secondary)
                Spacer()
                Text("Nothing here is required. Continue when ready.")
                    .font(.system(size: 11)).foregroundStyle(.tertiary)
            }
        }
        .padding(30)
    }

    private var memoryStep: some View {
        MemoryOnboardingStep()
    }

    private var doneStep: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 44)).foregroundStyle(Theme.accent)
                .symbolEffect(.bounce, value: step)
            Text("You're ready").font(.system(size: 26, weight: .semibold))
            Text("Kujto Studio is set up. Open a file in the sidebar to see the rules that apply, or type `kujto rules <file>` in your terminal.")
                .font(.system(size: 14)).foregroundStyle(.secondary)
                .multilineTextAlignment(.center).frame(maxWidth: 440)
        }
        .padding(40)
    }

    // MARK: - Helpers

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

// MARK: - Memory onboarding step

/// The "carry your memory everywhere" wizard step. Optional: the user can
/// connect a provider now or skip and do it later in Settings. Reuses the same
/// GitProvisioningService the settings tab drives.
private struct MemoryOnboardingStep: View {
    @ObservedObject private var provisioning = GitProvisioningService.shared
    @State private var kind: ProviderKind = .github

    var body: some View {
        VStack(spacing: 16) {
            StepTitle(icon: "arrow.triangle.2.circlepath", title: "Carry your memory everywhere",
                      subtitle: "Connect a git provider to create a private memory repo on your own account. Your rules, skills, and agents sync through your remote, never our servers. You can skip this and do it later.")

            Picker("Provider", selection: $kind) {
                Text("GitHub").tag(ProviderKind.github)
                Text("GitLab").tag(ProviderKind.gitlab)
                Text("Gitea").tag(ProviderKind.gitea)
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 320)

            Button("Connect \(kind.rawValue.capitalized)...") { provisioning.connect(kind: kind) }
                .buttonStyle(.borderedProminent)
                .disabled(isBusy)

            statusText
        }
        .padding(40)
        .frame(maxWidth: 500)
    }

    private var isBusy: Bool {
        switch provisioning.state {
        case .connecting, .awaitingApproval: return true
        default: return false
        }
    }

    @ViewBuilder
    private var statusText: some View {
        switch provisioning.state {
        case .idle:
            EmptyView()
        case .connecting:
            Text("Requesting a code...").font(.system(size: 12)).foregroundStyle(.secondary)
        case let .awaitingApproval(userCode, _):
            VStack(spacing: 4) {
                Text("Enter this code in the browser:").font(.system(size: 12)).foregroundStyle(.secondary)
                Text(userCode).font(.system(size: 18, weight: .semibold, design: .monospaced))
            }
        case let .provisioned(_, repo, created):
            Text("\(created ? "Created" : "Found") \(repo). Memory sync is ready.")
                .font(.system(size: 12)).foregroundStyle(Theme.success)
        case let .failed(message):
            Text(message).font(.system(size: 12)).foregroundStyle(Theme.danger)
                .multilineTextAlignment(.center)
        }
    }
}

// MARK: - Reusable pieces

private struct StepDots: View {
    let current: WelcomeView.Step
    var body: some View {
        HStack(spacing: 6) {
            ForEach(WelcomeView.Step.allCases, id: \.self) { s in
                Capsule()
                    .fill(s == current ? Theme.accent : Color.secondary.opacity(0.25))
                    .frame(width: s == current ? 18 : 6, height: 6)
                    .animation(.spring(response: 0.35), value: current)
            }
        }
    }
}

private struct StepTitle: View {
    let icon: String
    let title: String
    let subtitle: String
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: icon).labelStyle(.titleAndIcon)
                .font(.system(size: 20, weight: .semibold))
            Text(subtitle).font(.system(size: 13)).foregroundStyle(.secondary)
        }
    }
}

private struct RepoPickerCard: View {
    @ObservedObject var model: StudioModel
    let onPick: () -> Void
    var body: some View {
        HStack {
            Image(systemName: "folder.fill").foregroundStyle(Theme.accent)
            VStack(alignment: .leading, spacing: 2) {
                if let path = model.rootPath {
                    Text((path as NSString).lastPathComponent).font(.system(size: 14, weight: .medium))
                    Text(path).font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.tertiary).lineLimit(1).truncationMode(.middle)
                } else {
                    Text("No repo chosen yet").font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Button(model.rootPath == nil ? "Choose..." : "Change") { onPick() }
        }
        .padding(14)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.cardRadius))
        .overlay(RoundedRectangle(cornerRadius: Theme.cardRadius).stroke(.black.opacity(0.06)))
    }
}

/// Card showing which folder Kujto scans for repos. When empty, prompts the
/// user to pick one; when set, shows the path, the repo count, and controls
/// to rescan or swap the parent.
private struct ScanParentCard: View {
    let parent: URL?
    let repoCount: Int
    let onChoose: () -> Void
    let onRescan: () -> Void

    var body: some View {
        HStack {
            Image(systemName: parent == nil ? "folder.badge.questionmark" : "folder.fill")
                .foregroundStyle(Theme.accent)
            VStack(alignment: .leading, spacing: 2) {
                if let parent {
                    HStack(spacing: 6) {
                        Text(parent.lastPathComponent).font(.system(size: 14, weight: .medium))
                        Text("\(repoCount) \(repoCount == 1 ? "repo" : "repos")")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 1).padding(.horizontal, 6)
                            .background(.gray.opacity(0.12), in: Capsule())
                    }
                    Text(parent.path).font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.tertiary).lineLimit(1).truncationMode(.middle)
                } else {
                    Text("Scan folder for repos").font(.system(size: 14, weight: .medium))
                    Text("Pick where you keep your projects.")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                }
            }
            Spacer()
            if parent != nil {
                Button(action: onRescan) { Image(systemName: "arrow.clockwise") }
                    .help("Rescan")
                    .buttonStyle(.plain).foregroundStyle(.secondary)
            }
            Button(parent == nil ? "Choose..." : "Change") { onChoose() }
        }
        .padding(14)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.cardRadius))
        .overlay(RoundedRectangle(cornerRadius: Theme.cardRadius).stroke(.black.opacity(0.06)))
    }
}

/// Scrollable list of git repos discovered under the scan parent. Selecting
/// a row calls `onSelect(url)`, which the caller wires to `StudioModel.open`.
private struct DiscoveredReposList: View {
    let repos: [RepoEntry]
    let selectedPath: String?
    let onSelect: (URL) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if repos.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "sparkle.magnifyingglass").foregroundStyle(.secondary)
                    Text("No git repos found under this folder.")
                        .font(.system(size: 12)).foregroundStyle(.secondary)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.cardRadius))
                .overlay(RoundedRectangle(cornerRadius: Theme.cardRadius).stroke(.black.opacity(0.06)))
            } else {
                ScrollView {
                    VStack(spacing: 6) {
                        ForEach(repos, id: \.url) { repo in
                            DiscoveredRepoRow(
                                repo: repo,
                                isSelected: selectedPath == repo.url.path,
                                onSelect: { onSelect(repo.url) }
                            )
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .move(edge: .top)),
                                removal: .opacity
                            ))
                        }
                    }
                    .padding(4)
                    .animation(.spring(response: 0.35, dampingFraction: 0.85), value: repos.map(\.url))
                }
                .frame(maxHeight: 220)
                .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.cardRadius))
                .overlay(RoundedRectangle(cornerRadius: Theme.cardRadius).stroke(.black.opacity(0.06)))
            }
        }
    }
}

private struct DiscoveredRepoRow: View {
    let repo: RepoEntry
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 10) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "folder")
                    .foregroundStyle(isSelected ? Theme.accent : .secondary)
                    .frame(width: 20)
                VStack(alignment: .leading, spacing: 2) {
                    Text(repo.name).font(.system(size: 13, weight: .medium))
                    Text(repo.url.path).font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1).truncationMode(.middle)
                }
                Spacer()
                if let modified = repo.modified {
                    Text(relativeString(modified))
                        .font(.system(size: 11)).foregroundStyle(.tertiary)
                }
            }
            .padding(.vertical, 8).padding(.horizontal, 10)
            .background(
                isSelected ? Theme.accent.opacity(0.10) : Color.clear,
                in: RoundedRectangle(cornerRadius: 8)
            )
        }
        .buttonStyle(.plain)
    }

    private func relativeString(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

/// Summary of how many of the canonical agent files are symlinked in the
/// chosen repo. A quick "is this repo already wired?" glance so users don't
/// re-run wire needlessly.
private struct RepoWireBadge: View {
    let root: URL

    private var summary: (linked: Int, present: Int) {
        let fm = FileManager.default
        let names = ["AGENTS.md", "CLAUDE.md", "CODEX.md", "GEMINI.md",
                     ".cursorrules", ".github/copilot-instructions.md"]
        var linked = 0
        var present = 0
        for name in names {
            let path = root.appendingPathComponent(name).path
            guard fm.fileExists(atPath: path) else { continue }
            present += 1
            if let type = try? fm.attributesOfItem(atPath: path)[.type] as? FileAttributeType,
               type == .typeSymbolicLink {
                linked += 1
            }
        }
        return (linked, present)
    }

    var body: some View {
        let s = summary
        let wired = s.linked > 0
        HStack(spacing: 10) {
            Image(systemName: wired ? "link.circle.fill" : "link.circle")
                .foregroundStyle(wired ? .green : .secondary)
            VStack(alignment: .leading, spacing: 2) {
                if wired {
                    Text("This repo is already wired to Kujto")
                        .font(.system(size: 13, weight: .medium))
                    Text("\(s.linked) of 6 agent files linked. Re-running Wire is safe and idempotent.")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                } else if s.present > 0 {
                    Text("This repo has agent files but none are Kujto symlinks")
                        .font(.system(size: 13, weight: .medium))
                    Text("Kujto will not overwrite them. Wire creates symlinks only where nothing exists yet.")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                } else {
                    Text("This repo isn't wired yet")
                        .font(.system(size: 13, weight: .medium))
                    Text("Hit Continue and use the Agents panel to wire it.")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            (wired ? Color.green : Color.gray).opacity(0.08),
            in: RoundedRectangle(cornerRadius: Theme.cardRadius)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cardRadius)
                .stroke((wired ? Color.green : Color.gray).opacity(0.25))
        )
    }
}

private struct StatusRow: View {
    let component: InstallStatus.Component
    @State private var copied = false
    @State private var installError: String?
    @State private var installedFlash = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: iconName)
                .foregroundStyle(iconColor)
                .frame(width: 22)
                .padding(.top, 1)
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(component.name).font(.system(size: 14, weight: .medium))
                    Text(stateLabel)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(iconColor)
                        .padding(.vertical, 2).padding(.horizontal, 7)
                        .background(iconColor.opacity(0.12), in: Capsule())
                }
                Text(component.purpose)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 6) {
                    Image(systemName: "arrow.turn.down.right")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                    Text("Without it: \(component.skippedCost)")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let detail = component.detail {
                    Text(detail).font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.tertiary).lineLimit(1).truncationMode(.middle)
                }
                if let installError {
                    Text(installError)
                        .font(.system(size: 11)).foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 8)
            if let action, component.state != .ok {
                Button(actionLabel(for: action)) { perform(action) }
                    .controlSize(.small)
                    .tint(Theme.accent)
                    .buttonStyle(.borderedProminent)
                    .disabled(copied || installedFlash)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.cardRadius))
        .overlay(RoundedRectangle(cornerRadius: Theme.cardRadius).stroke(.black.opacity(0.06)))
    }

    private enum RowAction {
        case installCLI
        case copyCliInstall
        case openXcodeExtensions
        case installInVSCode
        case installInCursor

        var label: String {
            switch self {
            case .installCLI:          return "Install"
            case .copyCliInstall:      return "Copy install"
            case .openXcodeExtensions: return "Open Settings"
            case .installInVSCode:     return "Install"
            case .installInCursor:     return "Install"
            }
        }
    }

    private var action: RowAction? {
        switch component.key {
        // One-click install when this build bundles the CLI (direct build);
        // the App Store build can't ship it, so fall back to copying the
        // command.
        case "cli":    return CLIInstaller.canInstall ? .installCLI : .copyCliInstall
        case "xcode":  return .openXcodeExtensions
        case "vscode": return .installInVSCode
        case "cursor": return .installInCursor
        default:       return nil
        }
    }

    private func actionLabel(for action: RowAction) -> String {
        if copied { return "Copied" }
        if installedFlash { return "Installed" }
        return action.label
    }

    private func perform(_ action: RowAction) {
        installError = nil
        switch action {
        case .installCLI:
            do {
                let result = try CLIInstaller.install()
                installedFlash = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) { installedFlash = false }
                if result.needsPathHint {
                    let dir = result.installedPath.deletingLastPathComponent().path
                    installError = "Installed to \(result.installedPath.path). Add it to your PATH: export PATH=\"\(dir):$PATH\""
                }
            } catch let error as CLIInstaller.InstallError {
                if case .grantDenied = error { return }  // user cancelled, stay silent
                installError = error.errorDescription
            } catch {
                installError = error.localizedDescription
            }
        case .copyCliInstall:
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(InstallStatus.cliInstallCommand, forType: .string)
            copied = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { copied = false }
        case .openXcodeExtensions:
            let url = URL(string: "x-apple.systempreferences:com.apple.ExtensionsPreferences?extensionPointIdentifier=com.apple.dt.Xcode.extension.source-editor")!
            NSWorkspace.shared.open(url)
        case .installInVSCode:
            installEditorExtension(for: .vscode)
        case .installInCursor:
            installEditorExtension(for: .cursor)
        }
    }

    private func installEditorExtension(for editor: SharedConfig.Editor) {
        do {
            _ = try EditorExtensionInstaller.install(for: editor)
            installedFlash = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { installedFlash = false }
        } catch let error as EditorExtensionInstaller.InstallError {
            // Grant cancels are silent, everything else surfaces.
            if case .grantDenied = error { return }
            installError = error.errorDescription
        } catch {
            installError = error.localizedDescription
        }
    }
    private var iconName: String {
        switch component.state {
        case .ok:      return "checkmark.circle.fill"
        case .missing: return "circle.dashed"
        case .unknown: return "minus.circle"
        }
    }
    private var iconColor: Color {
        switch component.state {
        case .ok:      return .green
        case .missing: return Theme.accent
        case .unknown: return .gray
        }
    }
    private var stateLabel: String {
        switch component.state {
        case .ok:      return "installed"
        case .missing: return "optional"
        case .unknown: return "n/a"
        }
    }
}
