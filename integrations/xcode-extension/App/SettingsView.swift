import SwiftUI

/// App settings. Two tabs: Status (what is wired) and General (re-run
/// onboarding, reset). The onboarding wizard is reused verbatim from Welcome.
struct SettingsView: View {
    @ObservedObject var model: StudioModel
    @State private var showOnboarding = false

    var body: some View {
        TabView {
            StatusTab(model: model, showOnboarding: $showOnboarding)
                .tabItem { Label("Status", systemImage: "waveform.path.ecg") }
            GeneralTab(showOnboarding: $showOnboarding)
                .tabItem { Label("General", systemImage: "gearshape") }
        }
        .frame(width: 520, height: 460)
        .sheet(isPresented: $showOnboarding) {
            WelcomeView(model: model)
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
