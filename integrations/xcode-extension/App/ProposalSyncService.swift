import Foundation
import MultipeerConnectivity
import KujtoCore

/// Phase 7 transport: Bonjour peer sync for signed rule proposals, over
/// MultipeerConnectivity. It discovers teammates on the local network, sends
/// signed proposals, and verifies what it receives. Per the guardrail it never
/// installs a received rule: a valid signature earns a place in a review list,
/// and only a human adopts it.
///
/// Plain NSObject (not an actor) so the framework's off-main delegate callbacks
/// stay simple; every published mutation hops to the main queue.
final class ProposalSyncService: NSObject, ObservableObject {
    static let shared = ProposalSyncService()

    /// A received, signature-checked proposal awaiting human review.
    struct ReceivedProposal: Identifiable {
        let id: UUID
        let signed: SignedProposal
        let valid: Bool
        let fromPeer: String
    }

    @Published private(set) var isActive = false
    @Published private(set) var connectedPeers: [String] = []
    @Published private(set) var received: [ReceivedProposal] = []
    @Published var lastError: String?

    /// 1-15 chars, lowercase letters/digits/hyphen: MultipeerConnectivity rules.
    private let serviceType = "kujto-sync"
    private let myPeerID = MCPeerID(displayName: ProposalSyncService.localName())

    private lazy var session: MCSession = {
        let s = MCSession(peer: myPeerID, securityIdentity: nil, encryptionPreference: .required)
        s.delegate = self
        return s
    }()
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?

    // MARK: - Lifecycle

    func start() {
        guard !isActive else { return }
        let advertiser = MCNearbyServiceAdvertiser(peer: myPeerID, discoveryInfo: nil, serviceType: serviceType)
        advertiser.delegate = self
        advertiser.startAdvertisingPeer()
        self.advertiser = advertiser

        let browser = MCNearbyServiceBrowser(peer: myPeerID, serviceType: serviceType)
        browser.delegate = self
        browser.startBrowsingForPeers()
        self.browser = browser

        isActive = true
    }

    func stop() {
        advertiser?.stopAdvertisingPeer()
        browser?.stopBrowsingForPeers()
        session.disconnect()
        advertiser = nil
        browser = nil
        isActive = false
        connectedPeers = []
    }

    // MARK: - Sending

    /// Sends signed proposals to every connected peer. Encoding reuses the same
    /// canonical JSON the rest of Kujto signs and verifies.
    @discardableResult
    func send(_ proposals: [SignedProposal]) -> Bool {
        guard !session.connectedPeers.isEmpty, !proposals.isEmpty else { return false }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        do {
            for proposal in proposals {
                let data = try encoder.encode(proposal)
                try session.send(data, toPeers: session.connectedPeers, with: .reliable)
            }
            return true
        } catch {
            setError("Send failed: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Adopting (human-approved)

    /// Writes a received, valid proposal's draft into memory/. Refuses an
    /// invalid signature outright. Adoption is always this explicit call.
    func adopt(_ item: ReceivedProposal, into root: URL) throws {
        guard item.valid else {
            throw NSError(domain: "kujto.sync", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Refusing to adopt: signature is invalid."])
        }
        let dest = root
            .appendingPathComponent("memory/proposed")
            .appendingPathComponent("received-\(item.id.uuidString).md")
        try FileManager.default.createDirectory(at: dest.deletingLastPathComponent(), withIntermediateDirectories: true)
        try item.signed.proposal.draftMarkdown.write(to: dest, atomically: true, encoding: .utf8)
    }

    // MARK: - Helpers

    private static func localName() -> String {
        let raw = Host.current().localizedName ?? ProcessInfo.processInfo.hostName
        return String(raw.prefix(60))
    }

    private func onMain(_ block: @escaping () -> Void) {
        if Thread.isMainThread { block() } else { DispatchQueue.main.async(execute: block) }
    }

    private func setError(_ message: String) {
        onMain { self.lastError = message }
    }

    private func refreshPeers() {
        let names = session.connectedPeers.map { $0.displayName }
        onMain { self.connectedPeers = names }
    }
}

// MARK: - MCSessionDelegate

extension ProposalSyncService: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        refreshPeers()
    }

    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let signed = try? decoder.decode(SignedProposal.self, from: data) else { return }
        let valid = ProposalSigner.verify(signed)
        let item = ReceivedProposal(id: signed.proposal.id, signed: signed, valid: valid, fromPeer: peerID.displayName)
        onMain {
            // De-duplicate by proposal id.
            if !self.received.contains(where: { $0.id == item.id }) {
                self.received.insert(item, at: 0)
            }
        }
    }

    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}

// MARK: - Advertiser / Browser delegates

extension ProposalSyncService: MCNearbyServiceAdvertiserDelegate {
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser,
                    didReceiveInvitationFromPeer peerID: MCPeerID,
                    withContext context: Data?,
                    invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        // Accept invitations so proposals can flow; the payload is still
        // signature-checked on arrival and never auto-installed.
        invitationHandler(true, session)
    }

    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        setError("Advertise failed: \(error.localizedDescription)")
    }
}

extension ProposalSyncService: MCNearbyServiceBrowserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        browser.invitePeer(peerID, to: session, withContext: nil, timeout: 15)
    }

    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        refreshPeers()
    }

    func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        setError("Browse failed: \(error.localizedDescription)")
    }
}
