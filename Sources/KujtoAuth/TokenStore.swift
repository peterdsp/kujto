import Foundation
#if canImport(Security)
import Security
#endif

/// Where the provider access token lives. It is stored per machine and never
/// committed, never logged, never handed to an agent. The protocol lets tests
/// use an in-memory store while production uses the Keychain.
public protocol TokenStore: Sendable {
    func save(_ token: String, provider: String, account: String) throws
    func read(provider: String, account: String) -> String?
    func delete(provider: String, account: String) throws
}

/// A test and fallback store that keeps tokens in memory only.
public final class InMemoryTokenStore: TokenStore, @unchecked Sendable {
    private var tokens: [String: String] = [:]
    private let lock = NSLock()

    public init() {}

    private func key(_ provider: String, _ account: String) -> String { "\(provider)\u{1f}\(account)" }

    public func save(_ token: String, provider: String, account: String) throws {
        lock.lock(); defer { lock.unlock() }
        tokens[key(provider, account)] = token
    }

    public func read(provider: String, account: String) -> String? {
        lock.lock(); defer { lock.unlock() }
        return tokens[key(provider, account)]
    }

    public func delete(provider: String, account: String) throws {
        lock.lock(); defer { lock.unlock() }
        tokens[key(provider, account)] = nil
    }
}

#if canImport(Security)
/// The production store: a generic-password Keychain item per provider+account.
/// Not unit tested here (it touches the real Keychain); the in-memory store
/// covers the store contract, and this mirrors it.
public struct KeychainTokenStore: TokenStore {
    private let service: String

    public init(service: String = "dev.kujto.token") {
        self.service = service
    }

    private func query(_ provider: String, _ account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "\(provider):\(account)"
        ]
    }

    public func save(_ token: String, provider: String, account: String) throws {
        let data = Data(token.utf8)
        var q = query(provider, account)
        SecItemDelete(q as CFDictionary)
        q[kSecValueData as String] = data
        q[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let status = SecItemAdd(q as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw AuthError.provider("keychain save failed: \(status)")
        }
    }

    public func read(provider: String, account: String) -> String? {
        var q = query(provider, account)
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        guard SecItemCopyMatching(q as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    public func delete(provider: String, account: String) throws {
        let status = SecItemDelete(query(provider, account) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw AuthError.provider("keychain delete failed: \(status)")
        }
    }
}
#endif
