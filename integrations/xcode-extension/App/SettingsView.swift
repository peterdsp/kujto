import SwiftUI

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
