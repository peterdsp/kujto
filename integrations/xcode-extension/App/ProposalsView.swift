import SwiftUI
import KujtoCore

/// Phase 5 surface: review and adopt deterministic rule proposals. Kujto drafts
/// them; a human clicks Adopt to write one into memory/. Nothing is written
/// without that click, honoring the "never auto-write memory" guardrail.
struct ProposalsView: View {
    @ObservedObject var model: StudioModel

    @State private var proposals: [RuleProposal] = []
    @State private var loading = false
    @State private var adopted: Set<String> = []
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if loading {
                Text("Scanning for uncovered file groups…")
                    .font(.system(size: 13)).foregroundStyle(Theme.inkTertiary)
            } else if proposals.isEmpty {
                Text("No proposals. Every role group is already covered by a scoped rule.")
                    .font(.system(size: 13)).foregroundStyle(Theme.inkTertiary)
            } else {
                ForEach(proposals, id: \.suggestedPath) { proposal in
                    card(proposal)
                }
            }
            if let error {
                Text(error).font(.system(size: 12)).foregroundStyle(Theme.danger)
            }
        }
        .task(id: model.rootPath) { await load() }
    }

    private func card(_ proposal: RuleProposal) -> some View {
        PaperCard(weight: .muted) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text(proposal.title)
                        .font(.system(size: 15, weight: .medium, design: .serif))
                        .foregroundStyle(Theme.ink)
                    if adopted.contains(proposal.suggestedPath) {
                        SoftPill(text: "adopted", tone: .success)
                    }
                    Spacer(minLength: 0)
                }
                Text(proposal.rationale)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 6) {
                    ForEach(proposal.appliesTo, id: \.self) { glob in
                        Text(glob)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(Theme.inkSecondary)
                            .padding(.vertical, 2).padding(.horizontal, 6)
                            .background(Theme.cardMuted, in: Capsule())
                    }
                }
                DisclosureGroup("Draft") {
                    Text(proposal.draftMarkdown)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Theme.inkSecondary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 6)
                }
                .font(.system(size: 12))
                .tint(Theme.accent)

                if !adopted.contains(proposal.suggestedPath) {
                    Button("Adopt into \(proposal.suggestedPath)") { adopt(proposal) }
                        .buttonStyle(.borderedProminent)
                        .tint(Theme.accent)
                        .controlSize(.small)
                        .padding(.top, 2)
                }
            }
        }
    }

    private func load() async {
        guard let rootPath = model.rootPath else { proposals = []; return }
        loading = true
        let result = await Task.detached(priority: .userInitiated) {
            (try? RuleProposalEngine.propose(in: URL(fileURLWithPath: rootPath))) ?? []
        }.value
        proposals = result
        loading = false
    }

    /// Writing the draft into memory/ IS the human approval. Kujto never does
    /// this on its own; the button click is the consent.
    private func adopt(_ proposal: RuleProposal) {
        error = nil
        guard let rootPath = model.rootPath else { return }
        let dest = URL(fileURLWithPath: rootPath).appendingPathComponent(proposal.suggestedPath)
        do {
            try FileManager.default.createDirectory(
                at: dest.deletingLastPathComponent(), withIntermediateDirectories: true)
            try proposal.draftMarkdown.write(to: dest, atomically: true, encoding: .utf8)
            adopted.insert(proposal.suggestedPath)
        } catch {
            self.error = "Could not write \(proposal.suggestedPath): \(error.localizedDescription)"
        }
    }
}
