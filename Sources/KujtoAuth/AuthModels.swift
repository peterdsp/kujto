import Foundation

/// Errors from the auth and provisioning layer. Self-contained (KujtoAuth is a
/// distinct domain from the git primitives), with cases that map cleanly to
/// what the first-run wizard needs to show.
public enum AuthError: Error, Equatable, Sendable {
    /// The transport itself failed (no network, non-HTTP response).
    case transport(String)
    /// A response arrived but with an unexpected status for the call.
    case unexpectedStatus(Int)
    /// A body could not be decoded into the expected shape.
    case decoding(String)
    /// The user declined the authorization in the browser.
    case denied
    /// The device code expired before the user approved it.
    case expired
    /// The provider returned a named error we do not special-case.
    case provider(String)
    /// An operation needed a token but none was stored.
    case notAuthenticated
}

/// The grant returned by a device-authorization request. The wizard shows
/// `userCode` and opens `verificationURI`; the client polls with `deviceCode`.
public struct DeviceCodeGrant: Sendable, Equatable {
    public let deviceCode: String
    public let userCode: String
    public let verificationURI: String
    public let expiresIn: Int
    public let interval: Int

    public init(deviceCode: String, userCode: String, verificationURI: String, expiresIn: Int, interval: Int) {
        self.deviceCode = deviceCode
        self.userCode = userCode
        self.verificationURI = verificationURI
        self.expiresIn = expiresIn
        self.interval = interval
    }
}

/// The result of one token poll during device flow.
public enum TokenPollResult: Sendable, Equatable {
    case authorized(String)
    case pending
    case slowDown
    case expired
    case denied
    case error(String)
}

/// A repository reference as the provider reports it.
public struct RepoRef: Sendable, Equatable {
    public let fullName: String
    public let httpsURL: String
    public let sshURL: String
    public let isPrivate: Bool

    public init(fullName: String, httpsURL: String, sshURL: String, isPrivate: Bool) {
        self.fullName = fullName
        self.httpsURL = httpsURL
        self.sshURL = sshURL
        self.isPrivate = isPrivate
    }
}

/// What provisioning hands back to the wizard: which repo to sync and whether
/// this machine created it (first machine) or found it (a later machine).
public struct ProvisioningResult: Sendable, Equatable {
    public let login: String
    public let repo: RepoRef
    public let created: Bool

    public init(login: String, repo: RepoRef, created: Bool) {
        self.login = login
        self.repo = repo
        self.created = created
    }
}
