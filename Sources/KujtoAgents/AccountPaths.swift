import Foundation

/// Where the account files live. Centralized and overridable rather than
/// recomputed from the home directory at each call site, because
/// `homeDirectoryForCurrentUser` ignores `$HOME` on macOS: without an override
/// there is no way to exercise the real paths in a test or point a second
/// install at a different root.
public enum AccountPaths {
    /// Root for Kujto's per-user state. `KUJTO_HOME` overrides it, which is what
    /// tests and alternate installs use.
    public static func root(environment: [String: String] = ProcessInfo.processInfo.environment) -> URL {
        if let override = environment["KUJTO_HOME"], !override.isEmpty {
            return URL(fileURLWithPath: override)
        }
        return FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".kujto")
    }

    /// The synced memory repo, which holds `accounts.json`.
    public static func memoryDirectory(environment: [String: String] = ProcessInfo.processInfo.environment) -> URL {
        root(environment: environment).appendingPathComponent("memory-sync")
    }

    /// The file a shell hook sources to pick up the active account.
    public static func environmentFile(environment: [String: String] = ProcessInfo.processInfo.environment) -> URL {
        root(environment: environment).appendingPathComponent("active-account.sh")
    }

    /// Where a usage adapter writes its records.
    public static func usageFile(environment: [String: String] = ProcessInfo.processInfo.environment) -> URL {
        root(environment: environment).appendingPathComponent("usage.json")
    }
}
