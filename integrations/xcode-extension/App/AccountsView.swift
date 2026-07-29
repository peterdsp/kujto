import SwiftUI
import KujtoAgents

/// The accounts surface: every switchable account as a card, the active one
/// marked, usage on each, and a one-tap switch. Written in Kujto's own visual
/// language (paper cards, soft pills, serif headings) so it reads as part of
/// the Studio rather than a bolted-on panel.
struct AccountsView: View {
    @ObservedObject var model: StudioModel
    @ObservedObject private var accounts = AccountsService.shared
    @State private var editing: AccountProfile?
    @State private var showingNew = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                EditorialHeader(
                    eyebrow: "Accounts",
                    title: "Switch without losing the thread.",
                    subtitle: "Move between accounts, or between a subscription and Vertex, in one tap. Kujto writes a handoff note each time so the next assistant picks up where the last one stopped.")

                if accounts.roster.profiles.isEmpty {
                    emptyState
                } else {
                    ForEach(accounts.roster.profiles) { profile in
                        AccountCard(
                            profile: profile,
                            isActive: accounts.roster.activeID == profile.id,
                            usage: accounts.usage(for: profile),
                            onUse: { switchTo(profile) },
                            onEdit: { editing = profile },
                            onRemove: { accounts.remove(profile.id) })
                    }
                }

                HStack(spacing: 10) {
                    Button {
                        showingNew = true
                    } label: {
                        Label("Add account", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.accent)
                    .controlSize(.small)

                    Button("Refresh") { accounts.reload() }
                        .buttonStyle(.plain)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.accent)
                    Spacer()
                }

                if let message = accounts.message {
                    Text(message)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let handoff = accounts.lastHandoffPath {
                    Text("Handoff written to \((handoff as NSString).lastPathComponent). The next assistant reads it automatically.")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.inkTertiary)
                }
            }
            .padding(20)
        }
        .background(Theme.canvas)
        .onAppear { accounts.reload() }
        .sheet(isPresented: $showingNew) {
            AccountEditor(profile: AccountProfile(id: UUID().uuidString, label: "",
                                                  vendor: .claude, authMode: .subscription)) {
                accounts.upsert($0)
            }
        }
        .sheet(item: $editing) { profile in
            AccountEditor(profile: profile) { accounts.upsert($0) }
        }
    }

    private var emptyState: some View {
        PaperCard(weight: .muted) {
            VStack(alignment: .leading, spacing: 6) {
                Text("No accounts yet")
                    .font(.system(size: 15, weight: .medium, design: .serif))
                    .foregroundStyle(Theme.ink)
                Text("Add the account you use today, then add a second one. Switching becomes one tap, and the handoff note keeps the work continuous.")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func switchTo(_ profile: AccountProfile) {
        let root = model.rootPath.map { URL(fileURLWithPath: $0) }
        // Ground the handoff in what Kujto already knows about the open repo.
        let context = HandoffContext(
            repoName: root?.lastPathComponent,
            changedFiles: [],
            riskTags: [],
            task: nil)
        accounts.activate(profile.id, repoRoot: root, context: context)
    }
}

/// One account, as a paper card: who it is, how it authenticates, what it has
/// spent, and the action to make it active.
private struct AccountCard: View {
    let profile: AccountProfile
    let isActive: Bool
    let usage: UsageSnapshot?
    let onUse: () -> Void
    let onEdit: () -> Void
    let onRemove: () -> Void

    var body: some View {
        PaperCard(weight: isActive ? .standard : .muted) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: isActive ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(isActive ? Theme.accent : Theme.inkTertiary)
                    Text(profile.label.isEmpty ? "Untitled" : profile.label)
                        .font(.system(size: 16, weight: .medium, design: .serif))
                        .foregroundStyle(Theme.ink)
                    SoftPill(text: profile.vendor.rawValue, tone: .neutral)
                    SoftPill(text: modeLabel, tone: modeTone)
                    if isActive { SoftPill(text: "active", tone: .accent) }
                    Spacer()
                }

                if !profile.isReady {
                    Text("Needs \(profile.missingSettings.joined(separator: " and ")) before it can be used.")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.warning)
                }

                if let route = routeLine {
                    Text(route)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Theme.inkTertiary)
                }

                HStack(spacing: 10) {
                    Text(usage.map { $0.summary } ?? "No usage recorded")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.inkSecondary)
                    Spacer()
                    if !isActive {
                        Button("Use") { onUse() }
                            .buttonStyle(.borderedProminent)
                            .tint(Theme.accent)
                            .controlSize(.small)
                            .disabled(!profile.isReady)
                    }
                    Button("Edit") { onEdit() }
                        .buttonStyle(.plain)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.accent)
                    Button("Remove") { onRemove() }
                        .buttonStyle(.plain)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.danger)
                }
            }
        }
    }

    private var modeLabel: String {
        switch profile.authMode {
        case .subscription: return "subscription"
        case .apiKey: return "api key"
        case .vertex: return "vertex"
        case .bedrock: return "bedrock"
        }
    }

    private var modeTone: SoftPill.Tone {
        profile.authMode.isCloudHosted ? .warning : .success
    }

    /// The routing the switch will apply, shown so the user can see where their
    /// requests are about to go.
    private var routeLine: String? {
        switch profile.authMode {
        case .vertex:
            let project = profile.settings["vertexProject"] ?? "?"
            let region = profile.settings["vertexRegion"] ?? "?"
            return "vertex · \(project) · \(region)"
        case .bedrock:
            return "bedrock · \(profile.settings["awsRegion"] ?? "?")"
        case .apiKey, .subscription:
            return nil
        }
    }
}

/// Add or edit one account. Deliberately refuses to collect a secret: the
/// credential is captured by the surface that owns it and stored in the
/// Keychain, so nothing typed here can end up in the synced roster.
private struct AccountEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State var profile: AccountProfile
    let onSave: (AccountProfile) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(profile.label.isEmpty ? "New account" : "Edit account")
                .font(.system(size: 20, weight: .semibold, design: .serif))
                .foregroundStyle(Theme.ink)

            LabeledContent("Name") {
                TextField("Work, Personal, ...", text: $profile.label)
                    .textFieldStyle(.roundedBorder)
            }

            Picker("Assistant", selection: $profile.vendor) {
                ForEach(LLMVendor.allCases, id: \.self) { vendor in
                    Text(vendor.rawValue.capitalized).tag(vendor)
                }
            }

            Picker("Auth", selection: $profile.authMode) {
                Text("Subscription").tag(AuthMode.subscription)
                Text("API key").tag(AuthMode.apiKey)
                Text("Vertex AI").tag(AuthMode.vertex)
                Text("Bedrock").tag(AuthMode.bedrock)
            }
            .pickerStyle(.segmented)

            if profile.authMode == .vertex {
                LabeledContent("GCP project") {
                    TextField("my-project", text: binding("vertexProject"))
                        .textFieldStyle(.roundedBorder)
                }
                LabeledContent("Region") {
                    TextField("us-east5", text: binding("vertexRegion"))
                        .textFieldStyle(.roundedBorder)
                }
            }
            if profile.authMode == .bedrock {
                LabeledContent("AWS region") {
                    TextField("us-west-2", text: binding("awsRegion"))
                        .textFieldStyle(.roundedBorder)
                }
            }

            Text("Credentials are never typed here. They stay in your Keychain; this roster holds routing only, because it syncs.")
                .font(.system(size: 11))
                .foregroundStyle(Theme.inkTertiary)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Save") { onSave(profile); dismiss() }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.accent)
                    .disabled(profile.label.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 420)
        .background(Theme.canvas)
    }

    private func binding(_ key: String) -> Binding<String> {
        Binding(
            get: { profile.settings[key] ?? "" },
            set: { profile.settings[key] = $0 })
    }
}
