import SwiftUI

/// Modal editor for a Kujto skill's SKILL.md.
///
/// Reads the current markdown from the workspace copy, lets the user edit
/// it inline (typography-first, no chrome), and writes the result back.
/// Deliberately minimal: no frontmatter form, no blast-radius preview.
/// That work belongs to Phase C proper; this ships the "the file is mine
/// to edit" experience.
struct SkillEditor: View {
    let skill: SkillEntry
    var onSave: (() -> Void)?
    @Environment(\.dismiss) private var dismiss

    @State private var content: String = ""
    @State private var loaded = false
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            Divider().background(Theme.hairline)

            if loaded {
                editor
            } else {
                loadingState
            }

            Divider().background(Theme.hairline)

            footer
        }
        .frame(minWidth: 720, minHeight: 560)
        .background(Theme.canvas)
        .onAppear(perform: load)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("EDITING SKILL")
                .font(.system(size: 10, weight: .medium))
                .tracking(1.4)
                .foregroundStyle(Theme.inkTertiary)
            Text(skill.name)
                .font(.system(size: 22, weight: .semibold, design: .serif))
                .foregroundStyle(Theme.ink)
            Text("kujto-\(skill.slug) · SKILL.md")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(Theme.inkTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 28)
        .padding(.vertical, 20)
    }

    private var editor: some View {
        ScrollView {
            TextEditor(text: $content)
                .font(.system(size: 14, design: .monospaced))
                .scrollContentBackground(.hidden)
                .frame(minHeight: 380)
                .padding(.horizontal, 22)
                .padding(.vertical, 20)
        }
        .background(Theme.card)
    }

    private var loadingState: some View {
        Text("Loading…")
            .font(.system(size: 13))
            .foregroundStyle(Theme.inkTertiary)
            .padding(28)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var footer: some View {
        HStack {
            if let error {
                Text(error).font(.system(size: 12)).foregroundStyle(Theme.danger)
            } else {
                Text("Changes save to Kujto's local skill copy. Re-install to push them into a repo or global folder.")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.inkTertiary)
            }
            Spacer()
            Button("Cancel") { dismiss() }
                .buttonStyle(.plain)
                .foregroundStyle(Theme.inkSecondary)
            Button("Save") { save() }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
                .disabled(!loaded)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 14)
    }

    private func load() {
        let url = SkillsWorkspace.skillMarkdownURL(slug: skill.slug)
        if let text = try? String(contentsOf: url, encoding: .utf8) {
            content = text
        } else {
            content = ""
        }
        loaded = true
    }

    private func save() {
        do {
            try SkillsWorkspace.writeSkillMarkdown(slug: skill.slug, content: content)
            onSave?()
            dismiss()
        } catch let e {
            error = e.localizedDescription
        }
    }
}
