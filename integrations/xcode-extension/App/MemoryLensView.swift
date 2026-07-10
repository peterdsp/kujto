import SwiftUI
import KujtoCore

/// Phase 6 of the Repository Intelligence OS: Memory-Lens.
///
/// A compact, Kujto-owned floating window that follows the focused file and
/// shows its pre-flight at a glance: readiness, risk, the rules that apply, the
/// context that is missing, and the next action. Per the doc's guardrail this
/// is a real window, not a fragile global overlay: it needs no Accessibility or
/// Screen Recording permission, and a glass material plus a risk-colored top
/// rail encode confidence without decorating the data.
struct MemoryLensView: View {
    @ObservedObject var model: StudioModel
    @State private var preflight: AgentPreflight?
    @State private var loading = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            riskRail
            content
                .padding(16)
        }
        .frame(minWidth: 320, maxWidth: .infinity, minHeight: 360, maxHeight: .infinity, alignment: .topLeading)
        .background(.ultraThinMaterial)
        .task(id: lensKey) { await recompute() }
    }

    // MARK: - Sections

    /// A thin top rail whose color is the file's risk level. This is the
    /// "risk glow": it encodes confidence, it does not decorate.
    private var riskRail: some View {
        Rectangle()
            .fill(preflight.map { color(for: $0.risk.level) } ?? Theme.hairline)
            .frame(height: 3)
    }

    @ViewBuilder
    private var content: some View {
        if model.rootPath == nil {
            note("Open a repo in Kujto to use the lens.")
        } else if model.focusFile.isEmpty {
            note("Focus a file in the Codex (or the command palette) and its lens appears here.")
        } else if let pf = preflight {
            lens(pf)
        } else if loading {
            note("Reading memory for \((model.focusFile as NSString).lastPathComponent)…")
        } else {
            note("No lens for \(model.focusFile).")
        }
    }

    private func lens(_ pf: AgentPreflight) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header(pf)
                if !pf.matchedRulePaths.isEmpty { rulesSection(pf) }
                if !pf.suggestedTests.isEmpty { section("Tests to run", pf.suggestedTests) }
                if !pf.missingContext.isEmpty { section("Resolve first", pf.missingContext) }
                actionRow(pf)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func header(_ pf: AgentPreflight) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text((pf.file as NSString).lastPathComponent)
                .font(.system(size: 17, weight: .semibold, design: .serif))
                .foregroundStyle(Theme.ink)
            Text(pf.file)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(Theme.inkTertiary)
                .lineLimit(1)
                .truncationMode(.middle)
            HStack(spacing: 8) {
                pill(pf.readiness.label, tone: readinessTone(pf.readiness))
                pill("Risk \(pf.risk.level.label) · \(pf.risk.score)", tone: tone(for: pf.risk.level))
                pill("Ready \(pf.readinessScore)", tone: .neutral)
            }
            Text(pf.risk.headline)
                .font(.system(size: 12))
                .foregroundStyle(Theme.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(pf.file). Readiness \(pf.readiness.label), risk \(pf.risk.level.label) \(pf.risk.score) of 100. \(pf.risk.headline)")
    }

    private func rulesSection(_ pf: AgentPreflight) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            label("Rules that apply")
            ForEach(pf.matchedRulePaths, id: \.self) { path in
                Text(path)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Theme.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func section(_ title: String, _ items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            label(title)
            ForEach(items, id: \.self) { item in
                HStack(alignment: .top, spacing: 6) {
                    Text("•").font(.system(size: 11)).foregroundStyle(Theme.inkTertiary)
                    Text(item)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func actionRow(_ pf: AgentPreflight) -> some View {
        Text(pf.risk.action.label)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(pf.risk.level == .safe ? Theme.success : Theme.accent)
            .padding(.vertical, 7)
            .padding(.horizontal, 12)
            .background(pf.risk.level == .safe ? Theme.successSoft : Theme.accentSoft, in: Capsule())
    }

    // MARK: - Primitives

    private func label(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 9, weight: .medium))
            .tracking(1.2)
            .foregroundStyle(Theme.inkTertiary)
    }

    private func pill(_ text: String, tone: SoftPill.Tone) -> some View {
        SoftPill(text: text, tone: tone)
    }

    private func note(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13))
            .foregroundStyle(Theme.inkTertiary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Recompute

    private var lensKey: String { (model.rootPath ?? "") + "|" + model.focusFile }

    private func recompute() async {
        guard let rootPath = model.rootPath, !model.focusFile.isEmpty else {
            preflight = nil
            return
        }
        let file = model.focusFile
        loading = true
        let pf = await Task.detached(priority: .userInitiated) { () -> AgentPreflight? in
            let root = URL(fileURLWithPath: rootPath)
            let changed = GitDiff.changedFiles(in: root)
            return try? AgentSandbox.preflight(file: file, in: root, changedFiles: changed)
        }.value
        // Ignore a stale result if the focus moved on while we were computing.
        if file == model.focusFile { preflight = pf }
        loading = false
    }

    // MARK: - Palette

    private func color(for level: RiskScore.Level) -> Color {
        switch level {
        case .safe: return Theme.success
        case .watch: return Theme.warning
        case .escalating, .blocked: return Theme.danger
        }
    }

    private func tone(for level: RiskScore.Level) -> SoftPill.Tone {
        switch level {
        case .safe: return .success
        case .watch: return .warning
        case .escalating, .blocked: return .danger
        }
    }

    private func readinessTone(_ readiness: AgentPreflight.Readiness) -> SoftPill.Tone {
        switch readiness {
        case .ready: return .success
        case .needsContext: return .warning
        case .blocked: return .danger
        }
    }
}
