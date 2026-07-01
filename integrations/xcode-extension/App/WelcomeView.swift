import SwiftUI
import AppKit

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

    enum Step: Int, CaseIterable {
        case hello, pickRepo, wire, done
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
                .symbolEffect(.pulse, options: .repeating)
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
        VStack(alignment: .leading, spacing: 16) {
            StepTitle(icon: "folder", title: "Point Kujto at a repo",
                      subtitle: "Kujto reads memory from AGENTS.md, memory/, and the file layout. Everything stays on your machine.")
            RepoPickerCard(model: model, onPick: pickRepo)
            Spacer()
        }
        .padding(30)
    }

    private var wireStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            StepTitle(icon: "puzzlepiece.extension", title: "Where Kujto lives",
                      subtitle: "One engine, four surfaces. Kujto looks around your machine and reports what is already wired.")
            VStack(spacing: 10) {
                ForEach(status) { component in
                    StatusRow(component: component)
                        .transition(.opacity.combined(with: .move(edge: .leading)))
                }
            }
            .animation(.spring(response: 0.4), value: status)
            Button {
                withAnimation { status = InstallStatus.snapshot() }
            } label: {
                Label("Refresh status", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.plain).foregroundStyle(.secondary)
            Spacer()
        }
        .padding(30)
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

private struct StatusRow: View {
    let component: InstallStatus.Component
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconName)
                .foregroundStyle(iconColor)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(component.name).font(.system(size: 14, weight: .medium))
                if let detail = component.detail {
                    Text(detail).font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.tertiary).lineLimit(1).truncationMode(.middle)
                }
            }
            Spacer()
            Text(stateLabel)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(iconColor)
                .padding(.vertical, 3).padding(.horizontal, 8)
                .background(iconColor.opacity(0.12), in: Capsule())
        }
        .padding(12)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.cardRadius))
        .overlay(RoundedRectangle(cornerRadius: Theme.cardRadius).stroke(.black.opacity(0.06)))
    }
    private var iconName: String {
        switch component.state {
        case .ok:      return "checkmark.circle.fill"
        case .missing: return "exclamationmark.circle"
        case .unknown: return "questionmark.circle"
        }
    }
    private var iconColor: Color {
        switch component.state {
        case .ok:      return .green
        case .missing: return .orange
        case .unknown: return .gray
        }
    }
    private var stateLabel: String {
        switch component.state {
        case .ok: return "ok"
        case .missing: return "action needed"
        case .unknown: return "not detected"
        }
    }
}
