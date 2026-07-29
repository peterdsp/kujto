import Foundation

/// Which LLM vendor an account belongs to. Account switching is not
/// Claude-specific: the same profile, switch, and handoff machinery serves any
/// assistant the user runs, so adding a vendor is a case here plus an adapter.
public enum LLMVendor: String, Codable, Sendable, CaseIterable {
    case claude
    case openai
    case gemini
    case other
}

/// How an account authenticates. The distinction matters because it decides
/// what a switch has to move: a subscription swaps the stored OAuth
/// credential, an API key swaps an environment variable, and a cloud-hosted
/// backend swaps a whole set of routing variables.
public enum AuthMode: String, Codable, Sendable, CaseIterable {
    /// A logged-in consumer subscription (credential held by the tool itself).
    case subscription
    /// A direct API key billed to the vendor account.
    case apiKey
    /// The vendor's model served through Google Vertex AI.
    case vertex
    /// The vendor's model served through Amazon Bedrock.
    case bedrock

    /// True when activating this mode routes through a cloud provider rather
    /// than the vendor's own endpoint.
    public var isCloudHosted: Bool {
        self == .vertex || self == .bedrock
    }
}

/// One switchable account. Carries only non-secret routing data: the actual
/// credential lives in the Keychain under `credentialKey` and never appears
/// here, so a profile list is safe to persist, sync, and show.
public struct AccountProfile: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    /// What the user sees, for example "Work (Vertex)".
    public var label: String
    public var vendor: LLMVendor
    public var authMode: AuthMode
    /// Free-form routing values the adapter needs: for Vertex the GCP project
    /// and region, for Bedrock the AWS region. Never secrets.
    public var settings: [String: String]
    /// Keychain account name for this profile's credential, when it has one.
    public var credentialKey: String?

    public init(id: String, label: String, vendor: LLMVendor, authMode: AuthMode,
                settings: [String: String] = [:], credentialKey: String? = nil) {
        self.id = id
        self.label = label
        self.vendor = vendor
        self.authMode = authMode
        self.settings = settings
        self.credentialKey = credentialKey
    }

    /// Settings this profile is missing before it can be activated. Empty means
    /// ready. Checked up front so a switch fails with a clear list rather than
    /// half-applying and leaving the user on a broken account.
    public var missingSettings: [String] {
        switch authMode {
        case .subscription, .apiKey:
            return []
        case .vertex:
            return ["vertexProject", "vertexRegion"].filter { (settings[$0] ?? "").isEmpty }
        case .bedrock:
            return ["awsRegion"].filter { (settings[$0] ?? "").isEmpty }
        }
    }

    public var isReady: Bool { missingSettings.isEmpty }
}

/// The set of switchable accounts plus which one is active. Persisted in the
/// synced memory repo so the roster follows the user, exactly like the project
/// registry does.
public struct AccountRoster: Codable, Equatable, Sendable {
    public var profiles: [AccountProfile]
    public var activeID: String?

    public init(profiles: [AccountProfile] = [], activeID: String? = nil) {
        self.profiles = profiles
        self.activeID = activeID
    }

    public var active: AccountProfile? {
        activeID.flatMap { id in profiles.first { $0.id == id } }
    }

    public func profile(_ id: String) -> AccountProfile? {
        profiles.first { $0.id == id }
    }

    /// Insert or replace by id.
    public mutating func upsert(_ profile: AccountProfile) {
        if let index = profiles.firstIndex(where: { $0.id == profile.id }) {
            profiles[index] = profile
        } else {
            profiles.append(profile)
        }
    }

    public mutating func remove(_ id: String) {
        profiles.removeAll { $0.id == id }
        if activeID == id { activeID = nil }
    }

    /// Sorted by label for a stable, diff-friendly on-disk form.
    public func normalized() -> AccountRoster {
        AccountRoster(profiles: profiles.sorted { $0.label < $1.label }, activeID: activeID)
    }
}
