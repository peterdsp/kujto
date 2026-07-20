import Foundation

/// Finds or creates the user's private memory repo. On the first machine the
/// GET returns 404 and we create it private; on a later machine the GET returns
/// the existing repo and we leave it alone. Provider-agnostic: it only speaks
/// through `GitProvider`.
public struct MemoryRepoProvisioner: Sendable {
    private let provider: GitProvider
    private let transport: HTTPTransport

    public init(provider: GitProvider, transport: HTTPTransport) {
        self.provider = provider
        self.transport = transport
    }

    /// The authenticated user's login, needed to address their repos.
    public func currentUser(token: String) async throws -> String {
        let response = try await transport.send(provider.currentUserRequest(token: token))
        return try provider.parseUserLogin(response)
    }

    /// Ensures a private repo named `name` exists for `owner`. Returns the repo
    /// and whether this call created it.
    public func ensureRepo(owner: String, name: String, token: String) async throws -> (repo: RepoRef, created: Bool) {
        let getResponse = try await transport.send(provider.getRepoRequest(owner: owner, name: name, token: token))
        if let existing = try provider.parseRepo(getResponse) {
            return (existing, false)
        }
        // Not found: create it private.
        let createResponse = try await transport.send(
            provider.createRepoRequest(name: name, isPrivate: true, token: token))
        guard let created = try provider.parseRepo(createResponse) else {
            throw AuthError.provider("repo creation returned no repository")
        }
        return (created, true)
    }
}
