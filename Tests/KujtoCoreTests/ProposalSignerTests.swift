import XCTest
import CryptoKit
@testable import KujtoCore

final class ProposalSignerTests: XCTestCase {

    private func makeProposal(title: String = "Rules for Reducer files") -> PortableProposal {
        PortableProposal(
            title: title,
            appliesTo: ["**/*Reducer.swift"],
            draftMarkdown: "---\napplies_to:\n  - \"**/*Reducer.swift\"\n---\n# \(title)",
            author: "Jane Dev",
            repoName: "acme-ios",
            createdAt: Date(timeIntervalSince1970: 1_000_000)
        )
    }

    // MARK: - Sign / verify

    func testSignedProposalVerifies() throws {
        let key = Curve25519.Signing.PrivateKey()
        let signed = try ProposalSigner.sign(makeProposal(), with: key)
        XCTAssertTrue(ProposalSigner.verify(signed))
    }

    func testTamperedProposalFailsVerification() throws {
        let key = Curve25519.Signing.PrivateKey()
        let signed = try ProposalSigner.sign(makeProposal(), with: key)
        // Swap the payload for a different one; the signature no longer matches.
        let tampered = SignedProposal(
            proposal: makeProposal(title: "Evil rule"),
            publicKey: signed.publicKey,
            signature: signed.signature
        )
        XCTAssertFalse(ProposalSigner.verify(tampered))
    }

    func testWrongKeyFailsVerification() throws {
        let signer = Curve25519.Signing.PrivateKey()
        let attacker = Curve25519.Signing.PrivateKey()
        let signed = try ProposalSigner.sign(makeProposal(), with: signer)
        let forged = SignedProposal(
            proposal: signed.proposal,
            publicKey: attacker.publicKey.rawRepresentation,
            signature: signed.signature
        )
        XCTAssertFalse(ProposalSigner.verify(forged))
    }

    func testProvenanceSurvivesRoundTrip() throws {
        let key = Curve25519.Signing.PrivateKey()
        let signed = try ProposalSigner.sign(makeProposal(), with: key)
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        let data = try encoder.encode(signed)
        let decoded = try decoder.decode(SignedProposal.self, from: data)

        XCTAssertTrue(ProposalSigner.verify(decoded))
        XCTAssertEqual(decoded.proposal.author, "Jane Dev")
        XCTAssertEqual(decoded.proposal.repoName, "acme-ios")
        XCTAssertEqual(decoded.signerFingerprint, signed.signerFingerprint)
    }

    func testCanonicalBytesAreStable() throws {
        let p = makeProposal()
        XCTAssertEqual(try ProposalSigner.canonicalBytes(p), try ProposalSigner.canonicalBytes(p))
    }

    // MARK: - From RuleProposal

    func testPortableFromRuleProposalCarriesGlobs() {
        let rule = RuleProposal(
            title: "Rules for Client files",
            appliesTo: ["**/*Client.swift"],
            rationale: "3 files",
            affectedFiles: ["A.swift"],
            suggestedPath: "memory/proposed/client.md",
            draftMarkdown: "draft"
        )
        let portable = PortableProposal(rule, author: "x", repoName: "r")
        XCTAssertEqual(portable.appliesTo, ["**/*Client.swift"])
        XCTAssertEqual(portable.title, "Rules for Client files")
    }

    // MARK: - Local identity

    func testLocalIdentityPersistsAndReloads() throws {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("kujto-id-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("identity.key")

        let a = try LocalIdentity.loadOrCreate(at: url)
        let b = try LocalIdentity.loadOrCreate(at: url)
        XCTAssertEqual(a.fingerprint, b.fingerprint)

        // A proposal signed with the reloaded key verifies.
        let signed = try ProposalSigner.sign(makeProposal(), with: b.privateKey)
        XCTAssertTrue(ProposalSigner.verify(signed))
        XCTAssertEqual(signed.signerFingerprint, a.fingerprint)
    }
}
