import Foundation

/// The one call the first-run wizard makes for the golden path. It runs device
/// flow, stores the token in the Keychain (never on disk, never to any agent),
/// resolves the user, and finds or creates the private memory repo. The result
/// tells the wizard which repo to clone and whether this machine is the first.
public struct ProvisioningCoordinator: Sendable {
    private let provider: GitProvider
    private let deviceFlow: DeviceFlowClient
    private let provisioner: MemoryRepoProvisioner
    private let tokens: TokenStore
    private let repoName: String
    /// Scoped to repo administration and contents. Fine-grained tokens narrow
    /// this to the single memory repo where the provider supports it.
    private let scopes: [String]

    public init(
        provider: GitProvider,
        transport: HTTPTransport,
        tokens: TokenStore,
        sleeper: AuthSleeper = RealSleeper(),
        repoName: String = "kujto-memory",
        scopes: [String] = ["repo"]
    ) {
        self.provider = provider
        self.deviceFlow = DeviceFlowClient(provider: provider, transport: transport, sleeper: sleeper)
        self.provisioner = MemoryRepoProvisioner(provider: provider, transport: transport)
        self.tokens = tokens
        self.repoName = repoName
        self.scopes = scopes
    }

    /// Runs the whole golden path. `onPrompt` receives the device grant so the
    /// UI can show the user code and open the verification URL.
    public func provision(onPrompt: @Sendable (DeviceCodeGrant) -> Void) async throws -> ProvisioningResult {
        let token = try await deviceFlow.authorize(scopes: scopes, onPrompt: onPrompt)
        let login = try await provisioner.currentUser(token: token)
        // Store only after we know the token works (the user call succeeded).
        try tokens.save(token, provider: provider.name, account: login)

        let (repo, created) = try await provisioner.ensureRepo(owner: login, name: repoName, token: token)
        return ProvisioningResult(login: login, repo: repo, created: created)
    }

    /// The token for a known account, if this machine has already provisioned.
    public func storedToken(for login: String) -> String? {
        tokens.read(provider: provider.name, account: login)
    }
}
