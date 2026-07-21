import Foundation
import SwiftUI
import AppKit
import KujtoAuth

/// Runs the first-run provisioning golden path from the app: device flow, then
/// find-or-create the user's private memory repo. The client id is read from
/// build config or the environment, never hardcoded, so a deployment supplies
/// its own registered OAuth app.
///
/// The token is handled entirely by `KujtoAuth` (Keychain, never surfaced
/// here). This service only drives the flow and reflects its state to the UI.
@MainActor
final class GitProvisioningService: ObservableObject {
    enum State: Equatable {
        case idle
        case connecting
        /// Waiting for the user to approve in the browser. Carries the code to
        /// show and the page that was opened.
        case awaitingApproval(userCode: String, verificationURI: String)
        case provisioned(login: String, repo: String, created: Bool)
        case failed(String)
    }

    @Published private(set) var state: State = .idle

    static let shared = GitProvisioningService()

    /// Starts provisioning for a provider. Opens the verification page and shows
    /// the user code; completes when the user approves.
    func connect(kind: ProviderKind = .github) {
        guard !isRunning else { return }
        state = .connecting
        Task { await run(kind: kind) }
    }

    private var isRunning: Bool {
        if case .connecting = state { return true }
        if case .awaitingApproval = state { return true }
        return false
    }

    private func run(kind: ProviderKind) async {
        do {
            let config = try Self.loadConfig(kind: kind)
            let provider = try ProviderFactory.make(config)
            let coordinator = ProvisioningCoordinator(
                provider: provider,
                transport: URLSessionTransport(),
                tokens: Self.tokenStore())

            let result = try await coordinator.provision { grant in
                // The prompt fires off the coordinator's task; hop to the main
                // actor to update the UI and open the verification page.
                Task { @MainActor in
                    GitProvisioningService.shared.present(grant)
                }
            }
            state = .provisioned(login: result.login, repo: result.repo.fullName, created: result.created)
        } catch {
            state = .failed(Self.describe(error))
        }
    }

    private func present(_ grant: DeviceCodeGrant) {
        state = .awaitingApproval(userCode: grant.userCode, verificationURI: grant.verificationURI)
        if let url = URL(string: grant.verificationURI) {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: Config

    /// Resolves the client id (and Gitea base URL) from the app's Info.plist,
    /// with an environment override for development. Missing values surface as
    /// a clear provisioning error rather than a hardcoded placeholder.
    private static func loadConfig(kind: ProviderKind) throws -> ProviderConfig {
        let plistKey = "KujtoClientID_\(kind.rawValue.capitalized)"
        let envKey = "KUJTO_\(kind.rawValue.uppercased())_CLIENT_ID"
        let clientID = (Bundle.main.object(forInfoDictionaryKey: plistKey) as? String)
            ?? ProcessInfo.processInfo.environment[envKey]
            ?? ""

        var baseURL: URL?
        if kind == .gitea || kind == .gitlab {
            let baseString = (Bundle.main.object(forInfoDictionaryKey: "KujtoBaseURL_\(kind.rawValue.capitalized)") as? String)
                ?? ProcessInfo.processInfo.environment["KUJTO_\(kind.rawValue.uppercased())_BASE_URL"]
            baseURL = baseString.flatMap(URL.init(string:))
        }
        return ProviderConfig(kind: kind, clientID: clientID, baseURL: baseURL)
    }

    private static func tokenStore() -> TokenStore {
        #if canImport(Security)
        return KeychainTokenStore()
        #else
        return InMemoryTokenStore()
        #endif
    }

    private static func describe(_ error: Error) -> String {
        if let auth = error as? AuthError {
            switch auth {
            case .denied: return "You declined the authorization."
            case .expired: return "The code expired before approval. Try again."
            case .notAuthenticated: return "Not authenticated."
            case .transport(let m): return "Network error: \(m)"
            case .unexpectedStatus(let s): return "Unexpected response (\(s))."
            case .decoding(let m): return "Could not read the response: \(m)"
            case .provider(let m): return m
            }
        }
        return error.localizedDescription
    }
}
