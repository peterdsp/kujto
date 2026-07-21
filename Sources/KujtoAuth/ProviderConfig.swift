import Foundation

/// Which host to provision against. Drives the factory and the Keychain
/// account namespace.
public enum ProviderKind: String, Sendable, CaseIterable {
    case github
    case gitlab
    case gitea
}

/// The configuration a provider needs, resolved from build settings or the
/// environment rather than hardcoded. The `clientID` is a public device-flow
/// identifier (not a secret), but it is still deployment-specific, so it lives
/// in config; `baseURL` is required for Gitea (always self-hosted) and an
/// optional override for GitLab (self-managed instances).
public struct ProviderConfig: Sendable, Equatable {
    public let kind: ProviderKind
    public let clientID: String
    public let baseURL: URL?

    public init(kind: ProviderKind, clientID: String, baseURL: URL? = nil) {
        self.kind = kind
        self.clientID = clientID
        self.baseURL = baseURL
    }

    /// The account-store namespace for this provider.
    public var providerName: String { kind.rawValue }
}

/// Builds a `GitProvider` from a `ProviderConfig`, failing clearly when the
/// configuration is incomplete (missing client id, or a Gitea base URL). This
/// is the single place provider construction lives, so the app never hardcodes
/// a client id.
public enum ProviderFactory {
    public static func make(_ config: ProviderConfig) throws -> GitProvider {
        guard !config.clientID.isEmpty else {
            throw AuthError.provider("missing client id for \(config.kind.rawValue)")
        }
        switch config.kind {
        case .github:
            if let base = config.baseURL {
                return GitHubProvider(clientID: config.clientID, webBase: base,
                                      apiBase: base.appendingPathComponent("api/v3"))
            }
            return GitHubProvider(clientID: config.clientID)
        case .gitlab:
            if let base = config.baseURL {
                return GitLabProvider(clientID: config.clientID, base: base)
            }
            return GitLabProvider(clientID: config.clientID)
        case .gitea:
            guard let base = config.baseURL else {
                throw AuthError.provider("gitea requires a base URL")
            }
            return GiteaProvider(clientID: config.clientID, base: base)
        }
    }
}
