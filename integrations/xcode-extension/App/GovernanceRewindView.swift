import SwiftUI
import KujtoCore

/// Phase 4 surface: a time machine for a memory rule. Pick a rule, then drag a
/// slider back through its git revisions to see when it appeared and how its
/// risk tags and applies_to globs changed. Backed by RuleHistoryScanner; the
/// whole story is local.
struct GovernanceRewindView: View {
    @ObservedObject var model: StudioModel

    @State private var selectedRule: String = ""
    @State private var revisions: [RuleRevision] = []
    @State private var index: Double = 0
    @State private var loading = false

    private var rulePaths: [String] {
        let base = model.map?.baseRules ?? []
        let scoped = model.map?.scopedRules ?? []
        return (base + scoped).map { $0.path }.sorted()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            picker
            if loading {
                Text("Reading git history…")
                    .font(.system(size: 13)).foregroundStyle(Theme.inkTertiary)
            } else if selectedRule.isEmpty {
                Text("Pick a memory rule to rewind its history.")
                    .font(.system(size: 13)).foregroundStyle(Theme.inkTertiary)
            } else if revisions.isEmpty {
                Text("No committed history for this rule yet.")
                    .font(.system(size: 13)).foregroundStyle(Theme.inkTertiary)
            } else {
                timeline
            }
        }
        .task(id: selectedRule) { await load() }
    }

    private var picker: some View {
        HStack(spacing: 8) {
            Text("RULE")
                .font(.system(size: 9, weight: .medium)).tracking(1.2)
                .foregroundStyle(Theme.inkTertiary)
            Picker("Rule", selection: $selectedRule) {
                Text("Pick one…").tag("")
                ForEach(rulePaths, id: \.self) { path in
                    Text(path).tag(path)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
        }
    }

    @ViewBuilder
    private var timeline: some View {
        let clamped = min(max(Int(index), 0), revisions.count - 1)
        // Slider runs oldest (left) to newest (right); revisions are newest-first.
        let rev = revisions[revisions.count - 1 - clamped]
        VStack(alignment: .leading, spacing: 12) {
            if revisions.count > 1 {
                Slider(value: $index, in: 0...Double(revisions.count - 1), step: 1)
                HStack {
                    Text("oldest").font(.system(size: 10)).foregroundStyle(Theme.inkTertiary)
                    Spacer()
                    Text("\(clamped + 1) of \(revisions.count)")
                        .font(.system(size: 10)).foregroundStyle(Theme.inkTertiary)
                    Spacer()
                    Text("newest").font(.system(size: 10)).foregroundStyle(Theme.inkTertiary)
                }
            }
            revisionCard(rev)
        }
    }

    private func revisionCard(_ rev: RuleRevision) -> some View {
        PaperCard(weight: .muted) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text(rev.commit)
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundStyle(Theme.ink)
                    Text(rev.date).font(.system(size: 12)).foregroundStyle(Theme.inkSecondary)
                    Text("·").foregroundStyle(Theme.inkTertiary)
                    Text(rev.author).font(.system(size: 12)).foregroundStyle(Theme.inkSecondary)
                }
                Text(rev.subject)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 6) {
                    if rev.risk.isEmpty {
                        SoftPill(text: "no risk", tone: .neutral)
                    } else {
                        ForEach(rev.risk, id: \.self) { SoftPill(text: $0, tone: .danger) }
                    }
                }
                if !rev.appliesTo.isEmpty {
                    Text("globs: \(rev.appliesTo.joined(separator: ", "))")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Theme.inkTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Revision \(rev.commit), \(rev.date) by \(rev.author). \(rev.subject). \(rev.risk.isEmpty ? "No risk tags" : "Risk " + rev.risk.joined(separator: ", ")).")
    }

    private func load() async {
        guard let rootPath = model.rootPath, !selectedRule.isEmpty else {
            revisions = []
            return
        }
        loading = true
        let rule = selectedRule
        let result = await Task.detached(priority: .userInitiated) {
            RuleHistoryScanner.history(forRule: rule, in: URL(fileURLWithPath: rootPath))
        }.value
        if rule == selectedRule {
            revisions = result
            index = Double(max(0, result.count - 1)) // start on newest
        }
        loading = false
    }
}
