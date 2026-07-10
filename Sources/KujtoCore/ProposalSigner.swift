import Foundation
import CryptoKit

/// Phase 7 of the Repository Intelligence OS: the foundation P2P sync needs
/// before any networking exists. The doc's guardrail is strict: signed
/// proposals only, no automatic install. So this is the signed envelope and its
/// provenance, not a transport. A teammate can hand you a proposal; you verify
/// the signature, see who signed it and when, and only a human adopts it.
///
/// Ed25519 via CryptoKit. No network, no auto-write.

/// A rule proposal in a portable, signable form. Carries provenance so a
/// recipient can judge trust: who proposed it, from which repo, and when.
public struct PortableProposal: Codable, Sendable, Equatable {
    public let id: UUID
    public let title: String
    public let appliesTo: [String]
    public let draftMarkdown: String
    /// Provenance: a human-readable author label.
    public let author: String
    /// Provenance: the repo the proposal came from.
    public let repoName: String
    /// Provenance: when it was created.
    public let createdAt: Date

    public init(
        id: UUID = UUID(),
        title: String,
        appliesTo: [String],
        draftMarkdown: String,
        author: String,
        repoName: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.appliesTo = appliesTo
        self.draftMarkdown = draftMarkdown
        self.author = author
        self.repoName = repoName
        self.createdAt = createdAt
    }

    /// Lifts a locally-generated `RuleProposal` into a portable, signable form.
    public init(_ proposal: RuleProposal, author: String, repoName: String, createdAt: Date = Date()) {
        self.init(
            title: proposal.title,
            appliesTo: proposal.appliesTo,
            draftMarkdown: proposal.draftMarkdown,
            author: author,
            repoName: repoName,
            createdAt: createdAt
        )
    }
}

/// A proposal plus the signer's public key and an Ed25519 signature over its
/// canonical bytes. Integrity is verifiable; trust in the key is the human's
/// call, aided by the fingerprint.
public struct SignedProposal: Codable, Sendable, Equatable {
    public let proposal: PortableProposal
    /// Raw Ed25519 public key of the signer.
    public let publicKey: Data
    /// Signature over the proposal's canonical bytes.
    public let signature: Data

    public init(proposal: PortableProposal, publicKey: Data, signature: Data) {
        self.proposal = proposal
        self.publicKey = publicKey
        self.signature = signature
    }

    /// Short, human-comparable fingerprint of the signer's key.
    public var signerFingerprint: String {
        let digest = SHA256.hash(data: publicKey)
        return digest.prefix(8).map { String(format: "%02x", $0) }.joined()
    }
}

public enum ProposalSigner {

    /// Deterministic bytes to sign or verify: the proposal encoded with sorted
    /// keys and ISO-8601 dates, so signer and verifier agree byte-for-byte.
    public static func canonicalBytes(_ proposal: PortableProposal) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(proposal)
    }

    /// Signs a proposal with an Ed25519 private key.
    public static func sign(
        _ proposal: PortableProposal,
        with privateKey: Curve25519.Signing.PrivateKey
    ) throws -> SignedProposal {
        let bytes = try canonicalBytes(proposal)
        let signature = try privateKey.signature(for: bytes)
        return SignedProposal(
            proposal: proposal,
            publicKey: privateKey.publicKey.rawRepresentation,
            signature: signature
        )
    }

    /// True when the signature is valid for the proposal under the embedded
    /// public key. A tampered proposal, a wrong key, or a bad signature all
    /// return false. This proves integrity; it does not by itself confer trust.
    public static func verify(_ signed: SignedProposal) -> Bool {
        guard let publicKey = try? Curve25519.Signing.PublicKey(rawRepresentation: signed.publicKey),
              let bytes = try? canonicalBytes(signed.proposal) else {
            return false
        }
        return publicKey.isValidSignature(signed.signature, for: bytes)
    }
}

/// A persistent local signing identity. Load-or-create an Ed25519 key at a
/// path; the private key never leaves disk in cleartext beyond this file, which
/// the caller should keep out of version control.
public struct LocalIdentity {
    public let privateKey: Curve25519.Signing.PrivateKey

    public var publicKey: Curve25519.Signing.PublicKey { privateKey.publicKey }

    /// Short fingerprint of the public key, matching `SignedProposal`.
    public var fingerprint: String {
        SHA256.hash(data: publicKey.rawRepresentation).prefix(8)
            .map { String(format: "%02x", $0) }.joined()
    }

    public init(privateKey: Curve25519.Signing.PrivateKey) {
        self.privateKey = privateKey
    }

    /// Reads the key at `url`, or creates and persists a new one (file mode
    /// 0600) when none exists.
    public static func loadOrCreate(at url: URL) throws -> LocalIdentity {
        let fm = FileManager.default
        if fm.fileExists(atPath: url.path) {
            let raw = try Data(contentsOf: url)
            let key = try Curve25519.Signing.PrivateKey(rawRepresentation: raw)
            return LocalIdentity(privateKey: key)
        }
        let key = Curve25519.Signing.PrivateKey()
        try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try key.rawRepresentation.write(to: url, options: .atomic)
        try? fm.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
        return LocalIdentity(privateKey: key)
    }
}
