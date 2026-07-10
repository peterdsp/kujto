import SwiftUI
import KujtoCore

/// Phase 7 surface: peer sync for signed rule proposals. Start discovery, share
/// your signed proposals with teammates on the local network, and review what
/// arrives. A received proposal is signature-checked; adopting it is always a
/// human click, and an invalid signature can never be adopted.
struct SyncView: View {
    @ObservedObject var model: StudioModel
    @ObservedObject private var sync = ProposalSyncService.shared

    @State private var sharing = false
    @State private var shareNote: String?
    @State private var adoptNote: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            controls
            if sync.isActive { peersRow }
            if let shareNote { note(shareNote) }
            if let error = sync.lastError { note(error, tone: Theme.danger) }
            if !sync.received.isEmpty { receivedSection }
        }
    }

    private var controls: some View {
        HStack(spacing: 12) {
            Button(sync.isActive ? "Stop sync" : "Start sync") {
                sync.isActive ? sync.stop() : sync.start()
            }
            .buttonStyle(.borderedProminent)
            .tint(sync.isActive ? Theme.danger : Theme.accent)
            .controlSize(.small)

            if sync.isActive {
                Button("Share my proposals") { share() }
                    .buttonStyle(.plain)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.accent)
                    .disabled(sharing || sync.connectedPeers.isEmpty)
                if sharing { ProgressView().scaleEffect(0.5) }
            }
            Spacer(minLength: 0)
        }
    }

    private var peersRow: some View {
        HStack(spacing: 6) {
            Circle().fill(sync.connectedPeers.isEmpty ? Theme.inkTertiary : Theme.success)
                .frame(width: 7, height: 7)
            Text(sync.connectedPeers.isEmpty
                 ? "Discovering peers…"
                 : "Connected: \(sync.connectedPeers.joined(separator: ", "))")
                .font(.system(size: 12))
                .foregroundStyle(Theme.inkSecondary)
        }
    }

    private var receivedSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("RECEIVED PROPOSALS")
                .font(.system(size: 9, weight: .medium)).tracking(1.2)
                .foregroundStyle(Theme.inkTertiary)
            if let adoptNote { note(adoptNote, tone: Theme.success) }
            ForEach(sync.received) { item in
                PaperCard(weight: .muted) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Text(item.signed.proposal.title)
                                .font(.system(size: 14, weight: .medium, design: .serif))
                                .foregroundStyle(Theme.ink)
                            SoftPill(text: item.valid ? "signature valid" : "invalid",
                                     tone: item.valid ? .success : .danger)
                        }
                        Text("from \(item.fromPeer) · \(item.signed.proposal.author) · repo \(item.signed.proposal.repoName)")
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.inkTertiary)
                        Text("signer \(item.signed.signerFingerprint)")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(Theme.inkTertiary)
                        if item.valid {
                            Button("Adopt into memory/") { adopt(item) }
                                .buttonStyle(.plain)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(Theme.accent)
                                .padding(.top, 2)
                        } else {
                            Text("Not adoptable: verify the sender before trusting.")
                                .font(.system(size: 11)).foregroundStyle(Theme.danger)
                        }
                    }
                }
            }
        }
    }

    private func note(_ text: String, tone: Color = Theme.inkTertiary) -> some View {
        Text(text).font(.system(size: 12)).foregroundStyle(tone)
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Actions

    private func share() {
        guard let rootPath = model.rootPath else { return }
        sharing = true
        shareNote = nil
        Task {
            let signed = await Task.detached(priority: .userInitiated) { () -> [SignedProposal] in
                let root = URL(fileURLWithPath: rootPath)
                guard let proposals = try? RuleProposalEngine.propose(in: root), !proposals.isEmpty,
                      let identity = try? LocalIdentity.loadOrCreate(at: Self.keyURL()) else { return [] }
                return proposals.compactMap { proposal in
                    let portable = PortableProposal(proposal, author: NSFullUserName(), repoName: root.lastPathComponent)
                    return try? ProposalSigner.sign(portable, with: identity.privateKey)
                }
            }.value
            sharing = false
            if signed.isEmpty {
                shareNote = "Nothing to share: every role group is already covered."
            } else if sync.send(signed) {
                shareNote = "Shared \(signed.count) signed proposal(s) with connected peers."
            } else {
                shareNote = "No connected peers to share with yet."
            }
        }
    }

    private func adopt(_ item: ProposalSyncService.ReceivedProposal) {
        guard let rootPath = model.rootPath else { return }
        do {
            try sync.adopt(item, into: URL(fileURLWithPath: rootPath))
            adoptNote = "Adopted \"\(item.signed.proposal.title)\" into memory/proposed. Review and refine it."
        } catch {
            adoptNote = "Could not adopt: \(error.localizedDescription)"
        }
    }

    nonisolated private static func keyURL() -> URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".kujto/identity.key")
    }
}
