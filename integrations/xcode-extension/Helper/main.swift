import Foundation
import Security

// Kujto Runtime Helper
//
// Privileged daemon that Kujto Studio (a sandboxed app) delegates
// process-launching work to. Registered via `SMAppService.daemon` from the
// main app; talks to the app over an XPC listener at Mach service
// `dev.peterdsp.kujto.runtime`.
//
// Every command:
//   1. Declares its minimum capability tier.
//   2. Validates arguments against the never-touch deny-list.
//   3. Refuses if the caller's granted capability is lower than required.
//   4. Only THEN dispatches to `xcrun`.
//
// This is defence in depth - the client double-checks the same rules before
// sending. Either side alone can catch a mistake or bug.

// MARK: - Shared safety types (mirrored from KujtoCore/RuntimeSafety.swift)
//
// XPC cannot ship Swift types directly, so we redeclare the enum here as a
// raw string protocol. Keep in lockstep with KujtoCore/RuntimeSafety.swift.

enum HelperCapability: String {
    case observe, interact, build, modify

    var rank: Int {
        switch self {
        case .observe: return 0
        case .interact: return 1
        case .build: return 2
        case .modify: return 3
        }
    }
}

enum HelperNeverTouch {
    static let bundleIDPrefixes = [
        "com.apple.", "com.apple.keychain", "com.apple.securityd"
    ]
    static let pathFragments = [
        "/System/", "/Library/Keychains", "/private/etc", ".keychain-db"
    ]
    static func forbidsBundle(_ id: String) -> Bool {
        let lower = id.lowercased()
        return bundleIDPrefixes.contains { lower.hasPrefix($0.lowercased()) }
    }
    static func forbidsPath(_ path: String) -> Bool {
        pathFragments.contains { path.contains($0) }
    }
}

// MARK: - XPC protocol

/// Every reply signature is `(Data?, String?)` - response data on success,
/// error message on failure. String errors keep the XPC surface simple
/// (`Error` would need `NSSecureCoding` shenanigans).
@objc protocol KujtoRuntimeXPC {
    // Observe tier
    func ping(reply: @escaping (String) -> Void)
    func listSimulators(reply: @escaping (Data?, String?) -> Void)
    func screenshot(udid: String, destinationPath: String, grantedCapability: String,
                    reply: @escaping (Data?, String?) -> Void)
    func logShow(udid: String, predicate: String, lastMinutes: Int, grantedCapability: String,
                 reply: @escaping (Data?, String?) -> Void)

    // Interact tier
    func boot(udid: String, grantedCapability: String,
              reply: @escaping (Data?, String?) -> Void)
    func shutdown(udid: String, grantedCapability: String,
                  reply: @escaping (Data?, String?) -> Void)
    func launch(udid: String, bundleID: String, grantedCapability: String,
                reply: @escaping (Data?, String?) -> Void)
    func openURL(udid: String, url: String, grantedCapability: String,
                 reply: @escaping (Data?, String?) -> Void)
    func terminate(udid: String, bundleID: String, grantedCapability: String,
                   reply: @escaping (Data?, String?) -> Void)

    // Build tier
    func xcodebuild(arguments: [String], grantedCapability: String,
                    reply: @escaping (Data?, String?) -> Void)

    // Modify tier
    func eraseDevice(udid: String, grantedCapability: String,
                     reply: @escaping (Data?, String?) -> Void)
    func uninstall(udid: String, bundleID: String, grantedCapability: String,
                   reply: @escaping (Data?, String?) -> Void)
}

// MARK: - Service implementation

final class RuntimeService: NSObject, KujtoRuntimeXPC {

    // MARK: Observe

    func ping(reply: @escaping (String) -> Void) {
        reply("ok · kujto-runtime-helper v1")
    }

    func listSimulators(reply: @escaping (Data?, String?) -> Void) {
        runXcrun(["simctl", "list", "devices", "--json"], reply: reply)
    }

    func screenshot(udid: String, destinationPath: String, grantedCapability: String,
                    reply: @escaping (Data?, String?) -> Void) {
        guard authorize(.observe, grantedCapability, reply: reply) else { return }
        guard !HelperNeverTouch.forbidsPath(destinationPath) else {
            reply(nil, "path \(destinationPath) is on the never-touch list"); return
        }
        // Run simctl to write to `destinationPath`, then read the file back
        // and return its bytes over XPC. Sandboxed clients cannot read
        // arbitrary /tmp paths, so we hand them the data directly.
        let process = Process()
        process.launchPath = "/usr/bin/xcrun"
        process.arguments = ["simctl", "io", udid, "screenshot", destinationPath]
        process.standardOutput = Pipe()
        let stderr = Pipe()
        process.standardError = stderr
        do {
            try process.run()
            process.waitUntilExit()
            if process.terminationStatus == 0 {
                let bytes = (try? Data(contentsOf: URL(fileURLWithPath: destinationPath))) ?? Data()
                reply(bytes, nil)
            } else {
                let err = String(data: stderr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)
                reply(nil, err ?? "simctl exit \(process.terminationStatus)")
            }
        } catch let error {
            reply(nil, error.localizedDescription)
        }
    }

    func logShow(udid: String, predicate: String, lastMinutes: Int, grantedCapability: String,
                 reply: @escaping (Data?, String?) -> Void) {
        guard authorize(.observe, grantedCapability, reply: reply) else { return }
        var args = ["simctl", "spawn", udid, "log", "show", "--last", "\(lastMinutes)m"]
        if !predicate.isEmpty {
            args.append("--predicate")
            args.append(predicate)
        }
        runXcrun(args, reply: reply)
    }

    // MARK: Interact

    func boot(udid: String, grantedCapability: String,
              reply: @escaping (Data?, String?) -> Void) {
        guard authorize(.interact, grantedCapability, reply: reply) else { return }
        runXcrun(["simctl", "boot", udid], reply: reply)
    }

    func shutdown(udid: String, grantedCapability: String,
                  reply: @escaping (Data?, String?) -> Void) {
        guard authorize(.interact, grantedCapability, reply: reply) else { return }
        runXcrun(["simctl", "shutdown", udid], reply: reply)
    }

    func launch(udid: String, bundleID: String, grantedCapability: String,
                reply: @escaping (Data?, String?) -> Void) {
        guard authorize(.interact, grantedCapability, reply: reply) else { return }
        guard !HelperNeverTouch.forbidsBundle(bundleID) else {
            reply(nil, "bundle \(bundleID) is on the never-touch list"); return
        }
        runXcrun(["simctl", "launch", udid, bundleID], reply: reply)
    }

    func openURL(udid: String, url: String, grantedCapability: String,
                 reply: @escaping (Data?, String?) -> Void) {
        guard authorize(.interact, grantedCapability, reply: reply) else { return }
        guard !HelperNeverTouch.forbidsPath(url) else {
            reply(nil, "url \(url) is on the never-touch list"); return
        }
        runXcrun(["simctl", "openurl", udid, url], reply: reply)
    }

    func terminate(udid: String, bundleID: String, grantedCapability: String,
                   reply: @escaping (Data?, String?) -> Void) {
        guard authorize(.interact, grantedCapability, reply: reply) else { return }
        guard !HelperNeverTouch.forbidsBundle(bundleID) else {
            reply(nil, "bundle \(bundleID) is on the never-touch list"); return
        }
        runXcrun(["simctl", "terminate", udid, bundleID], reply: reply)
    }

    // MARK: Build

    func xcodebuild(arguments: [String], grantedCapability: String,
                    reply: @escaping (Data?, String?) -> Void) {
        guard authorize(.build, grantedCapability, reply: reply) else { return }
        for arg in arguments where HelperNeverTouch.forbidsPath(arg) {
            reply(nil, "argument \(arg) is on the never-touch list"); return
        }
        run("/usr/bin/xcrun", args: ["xcodebuild"] + arguments, reply: reply)
    }

    // MARK: Modify

    func eraseDevice(udid: String, grantedCapability: String,
                     reply: @escaping (Data?, String?) -> Void) {
        guard authorize(.modify, grantedCapability, reply: reply) else { return }
        runXcrun(["simctl", "erase", udid], reply: reply)
    }

    func uninstall(udid: String, bundleID: String, grantedCapability: String,
                   reply: @escaping (Data?, String?) -> Void) {
        guard authorize(.modify, grantedCapability, reply: reply) else { return }
        guard !HelperNeverTouch.forbidsBundle(bundleID) else {
            reply(nil, "bundle \(bundleID) is on the never-touch list"); return
        }
        runXcrun(["simctl", "uninstall", udid, bundleID], reply: reply)
    }

    // MARK: - Helpers

    private func authorize(
        _ required: HelperCapability,
        _ granted: String,
        reply: @escaping (Data?, String?) -> Void
    ) -> Bool {
        guard let grantedTier = HelperCapability(rawValue: granted) else {
            reply(nil, "unknown capability \(granted)")
            return false
        }
        if grantedTier.rank < required.rank {
            reply(nil, "needs \(required.rawValue), granted \(grantedTier.rawValue)")
            return false
        }
        return true
    }

    private func runXcrun(_ args: [String], reply: @escaping (Data?, String?) -> Void) {
        run("/usr/bin/xcrun", args: args, reply: reply)
    }

    private func run(_ path: String, args: [String], reply: @escaping (Data?, String?) -> Void) {
        let process = Process()
        process.launchPath = path
        process.arguments = args
        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr
        do {
            try process.run()
            process.waitUntilExit()
            let outData = stdout.fileHandleForReading.readDataToEndOfFile()
            let errData = stderr.fileHandleForReading.readDataToEndOfFile()
            if process.terminationStatus == 0 {
                reply(outData, nil)
            } else {
                let msg = String(data: errData, encoding: .utf8) ?? "exit \(process.terminationStatus)"
                reply(nil, msg)
            }
        } catch let error {
            reply(nil, error.localizedDescription)
        }
    }
}

// MARK: - Listener

final class HelperDelegate: NSObject, NSXPCListenerDelegate {
    /// The requirement string every accepted client must satisfy. Kujto Studio
    /// itself ships with team-ID YTS4KJBX3P; the requirement lets in only
    /// binaries whose designated code signature identifies as Kujto Studio
    /// and whose anchor is Apple's Developer ID.
    ///
    /// In dev ("Sign to Run Locally" ad-hoc signing) `SecCode` validation
    /// fails - the ad-hoc chain has no anchor. To keep local development
    /// unblocked we relax to team-ID-only in that case; production ships
    /// with the strict `anchor apple generic` requirement above.
    private static let clientRequirement =
        "identifier \"dev.peterdsp.kujto.studio\" and anchor apple generic and " +
        "certificate leaf[subject.OU] = \"YTS4KJBX3P\""

    func listener(_ listener: NSXPCListener,
                  shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        guard isTrustedClient(pid: newConnection.processIdentifier) else {
            // Reject silently; the client will see a connection error.
            return false
        }
        newConnection.exportedInterface = NSXPCInterface(with: KujtoRuntimeXPC.self)
        newConnection.exportedObject = RuntimeService()
        newConnection.resume()
        return true
    }

    /// Uses SecCode to check the calling process against a code requirement.
    /// Returns true only if the caller matches Kujto Studio's designated
    /// requirement - this is the sole line of defence against another
    /// binary talking to the daemon.
    private func isTrustedClient(pid: pid_t) -> Bool {
        let attrs = [kSecGuestAttributePid: NSNumber(value: pid)] as CFDictionary
        var guest: SecCode?
        guard SecCodeCopyGuestWithAttributes(nil, attrs, [], &guest) == errSecSuccess,
              let guest else {
            return false
        }
        var requirement: SecRequirement?
        guard SecRequirementCreateWithString(Self.clientRequirement as CFString, [], &requirement) == errSecSuccess,
              let requirement else {
            return false
        }
        return SecCodeCheckValidity(guest, [], requirement) == errSecSuccess
    }
}

let listener = NSXPCListener(machServiceName: "dev.peterdsp.kujto.runtime")
let delegate = HelperDelegate()
listener.delegate = delegate
listener.resume()
RunLoop.main.run()
