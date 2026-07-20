import SwiftUI
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
            // rulesStrip: step 3 renders the "Before you commit" strip here.
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
