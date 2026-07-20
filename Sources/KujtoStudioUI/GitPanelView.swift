import SwiftUI
import KujtoCore
import KujtoGit
import KujtoSync

/// The git panel: Glint's surface, native. A glass card with a branch header
/// and sync glyph, an unstaged and a staged section of change rows, and the
/// commit box. The step-3 rules fusion renders into `CommitBox` via the
/// `rulesStrip` slot; this step ships the surface with that slot empty.
public struct GitPanelView: View {
    @ObservedObject private var model: GitPanelModel

    public init(model: GitPanelModel) {
        self.model = model
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            Divider().overlay(model.theme.borderColor)
            sections
            Spacer(minLength: 0)
            CommitBox(model: model)
        }
        .padding(16)
        .background(
            ZStack {
                GlassBackground(isDark: model.theme.isDark)
                model.theme.tintColor.opacity(0.55)
            }
            .ignoresSafeArea()
        )
        .foregroundColor(model.theme.textPrimaryColor)
        .task { try? await model.refresh() }
    }

    private var header: some View {
        HStack {
            Image(systemName: "arrow.triangle.branch")
                .foregroundColor(model.theme.accentColor)
            Text(model.branch ?? "detached")
                .font(.headline)
            Spacer()
            SyncStatusBadge(status: model.syncStatus, theme: model.theme)
        }
    }

    private var sections: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                changeSection(title: "Changes", changes: model.unstaged, staged: false)
                if !model.staged.isEmpty {
                    changeSection(title: "Staged", changes: model.staged, staged: true)
                }
            }
        }
    }

    private func changeSection(title: String, changes: [GitChange], staged: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(title.uppercased())  (\(changes.count))")
                .font(.caption)
                .foregroundColor(model.theme.textSecondaryColor)
            if changes.isEmpty {
                Text(staged ? "Nothing staged" : "No changes")
                    .font(.callout)
                    .foregroundColor(model.theme.textSecondaryColor)
            } else {
                ForEach(changes, id: \.path) { change in
                    ChangeRow(change: change, staged: staged, theme: model.theme) {
                        Task { try? await (staged ? model.unstage(change) : model.stage(change)) }
                    }
                }
            }
        }
    }
}

/// One file row: a status glyph, the path, and a stage or unstage affordance.
struct ChangeRow: View {
    let change: GitChange
    let staged: Bool
    let theme: Theme
    let toggle: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Text(glyph)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(glyphColor)
                .frame(width: 16)
            Text(change.path)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
            Button(action: toggle) {
                Image(systemName: staged ? "minus.circle" : "plus.circle")
            }
            .buttonStyle(.plain)
            .foregroundColor(theme.accentColor)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 10)
        .background(theme.surfaceColor.opacity(0.5))
        .cornerRadius(8)
    }

    private var glyph: String {
        if change.isConflicted { return "U" }
        if change.isUntracked { return "?" }
        let state = staged ? change.index : change.worktree
        return String(state.rawValue).trimmingCharacters(in: .whitespaces).isEmpty
            ? "M" : String(state.rawValue)
    }

    private var glyphColor: Color {
        if change.isConflicted { return .red }
        if change.isUntracked { return theme.textSecondaryColor }
        return theme.accentColor
    }
}

/// The commit message field and button. `rulesStrip` is the slot the step-3
/// fusion fills with per-file risk tags and the confidence verdict; empty here.
struct CommitBox: View {
    @ObservedObject var model: GitPanelModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // rulesStrip: the fusion. Rules for the staged set, shown before commit.
            if let inspection = model.inspection, !inspection.isEmpty {
                CommitRulesStrip(inspection: inspection, theme: model.theme)
            }
            TextField("Commit message", text: $model.commitMessage)
                .textFieldStyle(.roundedBorder)
            HStack {
                Spacer()
                Button {
                    Task { try? await model.commit() }
                } label: {
                    Text("Commit \(model.staged.count) file\(model.staged.count == 1 ? "" : "s")")
                }
                .disabled(!model.canCommit)
            }
        }
    }
}

/// The "Before you commit" strip: the aggregate verdict, the risk tags, and the
/// tests to run for the staged set. Advisory, never blocking. This is the seam
/// where the git client becomes the enforcement point for the memory.
struct CommitRulesStrip: View {
    let inspection: CommitInspection
    let theme: Theme

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(verdictLabel)
                    .font(.caption.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(verdictColor.opacity(0.22))
                    .foregroundColor(verdictColor)
                    .cornerRadius(6)
                if !inspection.riskTags.isEmpty {
                    Text(inspection.riskTags.joined(separator: ", "))
                        .font(.caption)
                        .foregroundColor(theme.textSecondaryColor)
                }
                Spacer()
            }
            if !inspection.testsToRun.isEmpty {
                Text("Run: \(inspection.testsToRun.joined(separator: ", "))")
                    .font(.caption)
                    .foregroundColor(theme.textSecondaryColor)
                    .lineLimit(2)
                    .truncationMode(.middle)
            }
        }
        .padding(10)
        .background(verdictColor.opacity(0.08))
        .cornerRadius(8)
    }

    private var verdictLabel: String { inspection.verdict.label }

    private var verdictColor: Color {
        switch inspection.verdict {
        case .safe: return .green
        case .needsContext: return .yellow
        case .dangerZone: return .red
        }
    }
}

/// The menu-bar-style status glyph, one of synced, syncing, offline,
/// needs-attention, idle.
struct SyncStatusBadge: View {
    let status: SyncStatus
    let theme: Theme

    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label).font(.caption).foregroundColor(theme.textSecondaryColor)
        }
    }

    private var label: String {
        switch status {
        case .idle: return "idle"
        case .syncing: return "syncing"
        case .synced: return "synced"
        case .offline: return "offline"
        case .needsAttention: return "attention"
        }
    }

    private var color: Color {
        switch status {
        case .idle: return theme.textSecondaryColor
        case .syncing: return theme.accentColor
        case .synced: return .green
        case .offline: return .yellow
        case .needsAttention: return .red
        }
    }
}
