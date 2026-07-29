import SwiftUI
import KujtoAuth
import KujtoSync

/// App settings. Two tabs: Status (what is wired) and General (re-run
/// onboarding, reset). The onboarding wizard is reused verbatim from Welcome.
struct SettingsView: View {
    @ObservedObject var model: StudioModel
    @ObservedObject var updater: Updater
    @State private var showOnboarding = false

    var body: some View {
        TabView {
            StatusTab(model: model, showOnboarding: $showOnboarding)
                .tabItem { Label("Status", systemImage: "waveform.path.ecg") }
            MemorySyncTab()
                .tabItem { Label("Memory Sync", systemImage: "arrow.triangle.2.circlepath") }
            AccountsView(model: model)
                .tabItem { Label("Accounts", systemImage: "person.2") }
            AppearanceTab()
                .tabItem { Label("Appearance", systemImage: "paintbrush") }
            GeneralTab(showOnboarding: $showOnboarding)
                .tabItem { Label("General", systemImage: "gearshape") }
            UpdatesTab(updater: updater)
                .tabItem { Label("Updates", systemImage: "arrow.down.circle") }
        }
        .frame(width: 560, height: 480)
        .sheet(isPresented: $showOnboarding) {
            WelcomeView(model: model)
        }
    }
}

private struct UpdatesTab: View {
    @ObservedObject var updater: Updater
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            LabeledContent("Channel") { Text(updater.channelLabel).foregroundStyle(.secondary) }
            LabeledContent("Last check") {
                Text(updater.lastUpdateCheck.map(Self.format) ?? "never")
                    .foregroundStyle(.secondary)
            }
            Button("Check for updates now...") { updater.checkForUpdates() }
                .disabled(!updater.canCheck)
            Divider().padding(.vertical, 4)
            Text("The Direct build receives updates through Sparkle. The App Store build receives them through the system Software Update surface.")
                .font(.system(size: 12)).foregroundStyle(.secondary)
            Spacer()
        }
        .padding(20)
    }
    private static func format(_ date: Date) -> String {
        let f = DateFormatter(); f.dateStyle = .medium; f.timeStyle = .short; return f.string(from: date)
    }
}

/// Provisioning surface: connect a git provider so the memory repo can be
/// created and synced. The token is handled by KujtoAuth (Keychain); this tab
/// only drives the device-flow and reflects its state.
private struct MemorySyncTab: View {
    @ObservedObject private var provisioning = GitProvisioningService.shared
    @ObservedObject private var sync = MemorySyncService.shared
    @ObservedObject private var registry = RegistryService.shared
    @State private var kind: ProviderKind = .github

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Carry your memory everywhere")
                .font(.system(size: 14, weight: .medium))
            Text("Connect a git provider to create a private memory repo on your own account. Your rules, skills, and agents sync through your remote, never our servers.")
                .font(.system(size: 12)).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Picker("Provider", selection: $kind) {
                Text("GitHub").tag(ProviderKind.github)
                Text("GitLab").tag(ProviderKind.gitlab)
                Text("Gitea").tag(ProviderKind.gitea)
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 320)

            Button("Connect \(kind.rawValue.capitalized)...") { provisioning.connect(kind: kind) }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(isBusy)

            statusView

            Divider().padding(.vertical, 4)
            syncSection
            rehydrateSection
            Spacer()
        }
        .padding(20)
        .onAppear { registry.refreshPlan() }
    }

    @ViewBuilder
    private var rehydrateSection: some View {
        if registry.actionableCount > 0 {
            Divider().padding(.vertical, 4)
            VStack(alignment: .leading, spacing: 6) {
                Text("This machine is missing \(registry.actionableCount) of your projects.")
                    .font(.system(size: 12))
                Button("Re-clone and re-wire \(registry.actionableCount) project\(registry.actionableCount == 1 ? "" : "s")") {
                    registry.rehydrate()
                }
                .controlSize(.small)
            }
        }
        if let message = registry.message {
            Text(message).font(.system(size: 11)).foregroundStyle(.secondary)
        }
    }

    private var syncSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text("Background sync").font(.system(size: 13, weight: .medium))
                Circle().fill(syncColor).frame(width: 7, height: 7)
                Text(sync.status.rawValue).font(.system(size: 11)).foregroundStyle(.secondary)
                Spacer()
                Button(sync.isRunning ? "Stop" : "Start") {
                    sync.isRunning ? sync.stop() : sync.start()
                }
                .controlSize(.small)
                .disabled(!sync.isReady && !sync.isRunning)
            }
            if let message = sync.lastMessage {
                Text(message).font(.system(size: 11)).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if !sync.conflictFiles.isEmpty { conflictCard }
            if !sync.secretHits.isEmpty { secretCard }
        }
    }

    private var conflictCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Two versions of a rule").font(.system(size: 12, weight: .medium)).foregroundStyle(.red)
            Text(sync.conflictFiles.joined(separator: ", "))
                .font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary)
            HStack(spacing: 8) {
                Button("Keep both") { sync.resolveConflict(.keepBoth) }.controlSize(.small)
                Button("Keep mine") { sync.resolveConflict(.keepLocal) }.controlSize(.small)
                Button("Keep remote") { sync.resolveConflict(.keepRemote) }.controlSize(.small)
                Button("Abort") { sync.abortConflict() }.controlSize(.small)
            }
        }
        .padding(10)
        .background(Color.red.opacity(0.08))
        .cornerRadius(8)
    }

    private var secretCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Won't sync: possible secret").font(.system(size: 12, weight: .medium)).foregroundStyle(.red)
            ForEach(sync.secretHits, id: \.masked) { hit in
                Text("\(hit.file):\(hit.line) - \(hit.kind) (\(hit.masked))")
                    .font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary)
            }
            Text("Remove the secret from the file, then Start again.")
                .font(.system(size: 11)).foregroundStyle(.secondary)
        }
        .padding(10)
        .background(Color.red.opacity(0.08))
        .cornerRadius(8)
    }

    private var syncColor: Color {
        switch sync.status {
        case .idle: return .secondary
        case .syncing: return .accentColor
        case .synced: return .green
        case .offline: return .yellow
        case .needsAttention: return .red
        }
    }

    private var isBusy: Bool {
        switch provisioning.state {
        case .connecting, .awaitingApproval: return true
        default: return false
        }
    }

    @ViewBuilder
    private var statusView: some View {
        switch provisioning.state {
        case .idle:
            EmptyView()
        case .connecting:
            HStack(spacing: 8) { ProgressView().scaleEffect(0.5); Text("Requesting a code...").font(.system(size: 12)) }
        case let .awaitingApproval(userCode, uri):
            VStack(alignment: .leading, spacing: 4) {
                Text("Enter this code in the browser:").font(.system(size: 12)).foregroundStyle(.secondary)
                Text(userCode).font(.system(size: 18, weight: .semibold, design: .monospaced))
                Text(uri).font(.system(size: 11)).foregroundStyle(.secondary)
            }
        case let .provisioned(login, repo, created):
            Text("\(created ? "Created" : "Found") \(repo) for \(login). Memory sync is ready.")
                .font(.system(size: 12)).foregroundStyle(.green)
        case let .failed(message):
            Text(message).font(.system(size: 12)).foregroundStyle(.red)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct StatusTab: View {
    @ObservedObject var model: StudioModel
    @Binding var showOnboarding: Bool
    @State private var components: [InstallStatus.Component] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Installed surfaces").font(.system(size: 14, weight: .medium))
                Spacer()
                Button {
                    withAnimation { components = InstallStatus.snapshot() }
                } label: { Image(systemName: "arrow.clockwise") }
                    .buttonStyle(.plain).foregroundStyle(.secondary)
            }
            ForEach(components) { c in
                SettingsStatusRow(component: c)
                    .transition(.opacity)
            }
            Divider().padding(.vertical, 4)
            HStack {
                Text("Agents wired in the chosen repo").font(.system(size: 14, weight: .medium))
                Spacer()
                Text("\(model.linkedAgentCount) / \(model.agents.count)")
                    .font(.system(size: 12)).foregroundStyle(.secondary)
            }
            Button("Re-run setup...") { showOnboarding = true }
                .padding(.top, 6)
            Spacer()
        }
        .padding(20)
        .onAppear { components = InstallStatus.snapshot() }
    }
}

private struct AppearanceTab: View {
    @AppStorage("kujto.appearance") private var appearanceRaw: String = KujtoAppearancePreference.system.rawValue

    private var preference: KujtoAppearancePreference {
        get { KujtoAppearancePreference(rawValue: appearanceRaw) ?? .system }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Appearance").font(.system(size: 15, weight: .medium))
                Text("Kujto uses a warm editorial palette in every mode. OLED forces pure black surfaces for OLED and mini-LED displays.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Picker("Theme", selection: Binding(
                get: { preference },
                set: { appearanceRaw = $0.rawValue }
            )) {
                ForEach(KujtoAppearancePreference.allCases) { pref in
                    Text(pref.label).tag(pref)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            appearancePreview
            Spacer()
        }
        .padding(20)
    }

    /// Small side-by-side preview of the three concrete modes so users can
    /// see the palette differences without touching the picker.
    private var appearancePreview: some View {
        HStack(spacing: 12) {
            ThemeSwatch(mode: .light, title: "Light")
            ThemeSwatch(mode: .dark, title: "Dark")
            ThemeSwatch(mode: .oled, title: "OLED")
        }
    }
}

private struct ThemeSwatch: View {
    let mode: Theme.Mode
    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .bottomLeading) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(canvas)
                    .frame(height: 100)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(hairline, lineWidth: 0.5)
                    )
                VStack(alignment: .leading, spacing: 6) {
                    RoundedRectangle(cornerRadius: 4).fill(ink).frame(width: 60, height: 6)
                    RoundedRectangle(cornerRadius: 4).fill(inkSecondary).frame(width: 84, height: 4)
                    HStack(spacing: 4) {
                        Circle().fill(accent).frame(width: 8, height: 8)
                        RoundedRectangle(cornerRadius: 4).fill(inkTertiary).frame(width: 30, height: 4)
                    }
                }
                .padding(12)
            }
            Text(title).font(.system(size: 11, weight: .medium))
        }
    }

    // The Theme.dynamic colours resolve against the CURRENT mode. For the
    // swatch we need to pin a specific mode regardless of user choice, so
    // we build fixed sRGB colours per mode here.

    private var canvas: Color {
        switch mode {
        case .light: return Color(hex: 0xFAF7F2)
        case .dark:  return Color(hex: 0x1D1B20)
        case .oled:  return Color(hex: 0x000000)
        }
    }

    private var ink: Color {
        switch mode {
        case .light: return Color(hex: 0x1D1B20)
        case .dark:  return Color(hex: 0xF5F0EA)
        case .oled:  return Color(hex: 0xFAFAFA)
        }
    }

    private var inkSecondary: Color { ink.opacity(0.55) }
    private var inkTertiary: Color  { ink.opacity(0.35) }
    private var accent: Color {
        mode == .light ? Color(hex: 0x7C6CF0) : Color(hex: 0x9B8DF5)
    }
    private var hairline: Color { ink.opacity(0.12) }
}

private struct GeneralTab: View {
    @Binding var showOnboarding: Bool
    @AppStorage("kujto.hasOnboarded") private var hasOnboarded: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            LabeledContent("First-run wizard") {
                HStack {
                    Text(hasOnboarded ? "Completed" : "Not shown yet")
                        .foregroundStyle(hasOnboarded ? .green : .secondary)
                    Spacer()
                    Button("Show again") { showOnboarding = true }
                }
            }
            LabeledContent("Reset onboarding") {
                Button("Forget") { hasOnboarded = false }
            }
            Divider().padding(.vertical, 4)
            Text("Kujto Studio keeps your repo memory local. Nothing is uploaded.")
                .font(.system(size: 12)).foregroundStyle(.secondary)
            Spacer()
        }
        .padding(20)
    }
}

private struct SettingsStatusRow: View {
    let component: InstallStatus.Component
    var body: some View {
        HStack {
            Image(systemName: iconName).foregroundStyle(iconColor).frame(width: 20)
            Text(component.name).font(.system(size: 13))
            Spacer()
            if let detail = component.detail {
                Text(detail)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1).truncationMode(.middle)
            }
        }
    }
    private var iconName: String {
        switch component.state {
        case .ok: return "checkmark.circle.fill"
        case .missing: return "exclamationmark.circle"
        case .unknown: return "questionmark.circle"
        }
    }
    private var iconColor: Color {
        switch component.state {
        case .ok: return .green
        case .missing: return .orange
        case .unknown: return .gray
        }
    }
}
