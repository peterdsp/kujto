import Foundation

/// Reads and writes the account roster as `accounts.json` at the root of the
/// synced memory repo, so the roster travels with the user's memory the same
/// way the project registry does. Serialization is stable (sorted keys,
/// normalized order) to keep the synced file merge-clean.
///
/// Only routing data is written. Credentials stay in the Keychain, and the
/// store refuses to write a profile whose settings look like a secret, so a
/// mistake cannot put a key into a file that syncs to a remote.
public struct AccountRosterStore: Sendable {
    private let repo: URL

    public init(repo: URL) {
        self.repo = repo
    }

    private var url: URL { repo.appendingPathComponent("accounts.json") }

    public func load() throws -> AccountRoster {
        guard FileManager.default.fileExists(atPath: url.path) else { return AccountRoster() }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(AccountRoster.self, from: data)
    }

    public func save(_ roster: AccountRoster) throws {
        if let offender = Self.settingThatLooksSecret(in: roster) {
            throw AccountStoreError.refusedSecretInSettings(offender)
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(roster.normalized())
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
    }

    /// Names a setting whose key or value looks like a credential. Routing
    /// values are short and structural; a token is neither, so this catches the
    /// realistic mistake without rejecting a project id or a region.
    static func settingThatLooksSecret(in roster: AccountRoster) -> String? {
        let suspiciousKeys = ["token", "secret", "password", "apikey", "api_key", "credential"]
        for profile in roster.profiles {
            for (key, value) in profile.settings {
                let lowered = key.lowercased().replacingOccurrences(of: "-", with: "")
                if suspiciousKeys.contains(where: { lowered.contains($0) }) {
                    return "\(profile.id).\(key)"
                }
                if Self.looksLikeToken(value) {
                    return "\(profile.id).\(key)"
                }
            }
        }
        return nil
    }

    /// A long unbroken run of token-ish characters, or a known vendor prefix.
    static func looksLikeToken(_ value: String) -> Bool {
        let prefixes = ["sk-", "ghp_", "gho_", "xox", "AKIA", "AIza", "glpat"]
        if prefixes.contains(where: { value.hasPrefix($0) }) { return true }
        guard value.count >= 32 else { return false }
        return value.allSatisfy { $0.isLetter || $0.isNumber || $0 == "_" || $0 == "-" }
    }
}

public enum AccountStoreError: Error, Equatable, Sendable {
    /// A setting looked like a credential; nothing was written.
    case refusedSecretInSettings(String)
}
