import Foundation

/// Capability tiers for the Kujto runtime helper. Each XPC command declares
/// the minimum capability it needs; the client sends the user's current
/// maximum tier alongside the request; the helper double-checks before
/// dispatching. Defence-in-depth so a compromised app can't escalate.
public enum RuntimeCapability: String, Codable, CaseIterable, Sendable, Comparable {
    /// Read-only. Screenshot, log show, list devices, ping.
    case observe
    /// State-changing but reversible. Boot, shutdown, launch, openurl.
    case interact
    /// Creates artifacts. xcodebuild run / test.
    case build
    /// Destructive. Erase device, uninstall app, keychain touch.
    case modify

    public static func < (lhs: RuntimeCapability, rhs: RuntimeCapability) -> Bool {
        rank(lhs) < rank(rhs)
    }

    private static func rank(_ c: RuntimeCapability) -> Int {
        switch c {
        case .observe:  return 0
        case .interact: return 1
        case .build:    return 2
        case .modify:   return 3
        }
    }

    public var displayName: String {
        switch self {
        case .observe:  return "Observe"
        case .interact: return "Interact"
        case .build:    return "Build"
        case .modify:   return "Modify"
        }
    }

    public var summary: String {
        switch self {
        case .observe:  return "Read simulator state. Screenshots, logs, device list."
        case .interact: return "Change simulator state. Boot, launch, open URL. Reversible."
        case .build:    return "Run xcodebuild. Compiles and executes tests."
        case .modify:   return "Destructive. Erase a device, uninstall an app."
        }
    }
}

/// Absolute deny-list. Nothing Kujto's helper will do, at any capability
/// tier, ever. Enforced both in the client (defence in depth) and in the
/// helper (last line of defence) so a bug on either side can't punch through.
public enum RuntimeNeverTouch {
    /// Bundle IDs that look like production identifiers or Apple system
    /// bundles. Match is prefix-based, case-insensitive.
    public static let bundleIDPrefixes = [
        "com.apple.",
        "com.apple.keychain",
        "com.apple.securityd",
        "com.apple.SecurityAgent",
        "com.apple.KeychainAccess"
    ]

    /// Path fragments the helper refuses to touch. Any URL/argument that
    /// contains one of these as a substring is rejected.
    public static let pathFragments = [
        "/System/",
        "/Library/Keychains",
        "/private/etc",
        ".keychain-db",
        "keychain-2.db"
    ]

    /// Simulator UDIDs the app has explicitly marked as production and off
    /// limits. Empty by default; wired to per-repo config in a follow-up.
    public static var pinnedProductionUDIDs: Set<String> = []

    /// True if `bundleID` matches any deny-list prefix.
    public static func forbidsBundle(_ bundleID: String) -> Bool {
        let lower = bundleID.lowercased()
        return bundleIDPrefixes.contains { lower.hasPrefix($0.lowercased()) }
    }

    /// True if `path` (or any argument that could be a path) hits the
    /// path-fragment deny-list.
    public static func forbidsPath(_ path: String) -> Bool {
        pathFragments.contains { path.contains($0) }
    }
}

/// Error thrown across the XPC boundary when a request is denied. The
/// helper serialises it as a string for XPC compatibility; the client
/// re-parses on receipt.
public enum RuntimeSafetyError: Error, CustomStringConvertible {
    case capabilityTooHigh(required: RuntimeCapability, granted: RuntimeCapability)
    case forbiddenBundle(String)
    case forbiddenPath(String)
    case forbiddenProductionDevice(String)

    public var description: String {
        switch self {
        case .capabilityTooHigh(let required, let granted):
            return "Kujto refused: needs \(required.displayName), granted \(granted.displayName)."
        case .forbiddenBundle(let id):
            return "Kujto refused: bundle \(id) is on the never-touch list."
        case .forbiddenPath(let path):
            return "Kujto refused: path \(path) is on the never-touch list."
        case .forbiddenProductionDevice(let udid):
            return "Kujto refused: device \(udid) is pinned as production."
        }
    }
}
