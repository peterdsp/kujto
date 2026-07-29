import Foundation
import SwiftUI
import KujtoAgents
import KujtoCore

/// App-side owner of the account roster: loads it from the synced memory repo,
/// performs switches through the tested engine, and publishes usage so the
/// menu bar and settings can render it.
///
/// All decisions live in KujtoAgents; this is the glue that binds it to the
/// app's lifecycle and to where the user's files actually are.
@MainActor
final class AccountsService: ObservableObject {
    @Published private(set) var roster = AccountRoster()
    @Published private(set) var usage: [String: UsageSnapshot] = [:]
    @Published private(set) var message: String?
    @Published private(set) var lastHandoffPath: String?

    static let shared = AccountsService()

    private let tracker = UsageTracker()

    /// Where the roster lives: alongside the rest of the synced memory.
    private var memoryDir: URL { AccountPaths.memoryDirectory() }

    /// The file a shell hook sources to pick up the active account.
    private var envFile: URL { AccountPaths.environmentFile() }

    /// Usage records, as an adapter writes them. One JSON array of records;
    /// absent means no usage has been recorded yet, which is shown as such
    /// rather than as zero.
    private var usageFile: URL { AccountPaths.usageFile() }

    private var store: AccountRosterStore { AccountRosterStore(repo: memoryDir) }

    var active: AccountProfile? { roster.active }

    /// True when there is more than one account to move between.
    var canSwitch: Bool { roster.profiles.count > 1 }

    func reload() {
        do {
            roster = try store.load()
        } catch {
            message = "Could not read accounts: \(error.localizedDescription)"
        }
        reloadUsage()
    }

    func usage(for profile: AccountProfile) -> UsageSnapshot? {
        usage[profile.id]
    }

    /// Switches to `id`, writing a handoff note into the currently open repo so
    /// the next account continues the work instead of starting cold.
    func activate(_ id: String, repoRoot: URL?, context: HandoffContext = HandoffContext()) {
        let switcher = AccountSwitcher(applier: FileEnvironmentApplier(url: envFile))
        var working = roster
        // Resolve the credential up front: the applier's callback is
        // non-isolated, so the Keychain read has to happen on the main actor
        // here rather than inside it.
        let resolved = credential(for: id)
        do {
            let outcome = try switcher.activate(
                id, in: &working, context: context,
                timestamp: ISO8601DateFormatter().string(from: Date()),
                handoffRoot: repoRoot,
                secret: { resolved })

            switch outcome {
            case let .switched(_, handoffPath):
                roster = working
                try? store.save(working)
                lastHandoffPath = handoffPath
                message = "Now on \(working.active?.label ?? id)."
            case .alreadyActive:
                message = "Already on that account."
            case let .incomplete(missing):
                message = "Add \(missing.joined(separator: " and ")) before switching."
            case .unknownProfile:
                message = "That account is no longer in the roster."
            }
        } catch {
            message = "Switch failed: \(error.localizedDescription)"
        }
    }

    /// Adds or updates a profile and persists the roster.
    func upsert(_ profile: AccountProfile) {
        var working = roster
        working.upsert(profile)
        do {
            try store.save(working)
            roster = working
            message = nil
        } catch let error as AccountStoreError {
            if case let .refusedSecretInSettings(field) = error {
                message = "Refused to save: \(field) looks like a credential. Keep secrets out of settings."
            }
        } catch {
            message = "Could not save: \(error.localizedDescription)"
        }
    }

    func remove(_ id: String) {
        var working = roster
        working.remove(id)
        try? store.save(working)
        roster = working
    }

    // MARK: Internals

    /// The stored credential for a profile. Read from the Keychain at the
    /// moment of the switch and never held on this object.
    private func credential(for id: String) -> String? {
        guard let profile = roster.profile(id), let key = profile.credentialKey else { return nil }
        return KeychainCredential.read(account: key)
    }

    private func reloadUsage() {
        guard let data = try? Data(contentsOf: usageFile),
              let raw = try? JSONDecoder().decode([UsageRecordFile].self, from: data) else {
            usage = [:]
            return
        }
        let records = raw.map {
            UsageTracker.Record(profileID: $0.profileID, inputTokens: $0.inputTokens,
                                outputTokens: $0.outputTokens, costUSD: $0.costUSD,
                                sessionID: $0.sessionID)
        }
        usage = Dictionary(uniqueKeysWithValues:
            tracker.snapshots(from: records).map { ($0.profileID, $0) })
    }

    /// On-disk shape of a usage record.
    private struct UsageRecordFile: Codable {
        var profileID: String
        var inputTokens: Int
        var outputTokens: Int
        var costUSD: Double?
        var sessionID: String?
    }
}

/// Minimal Keychain read for account credentials. Writing is done by whichever
/// surface captured the credential; this service only ever reads, and only at
/// the moment of a switch.
enum KeychainCredential {
    static let service = "dev.kujto.account"

    static func read(account: String) -> String? {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
