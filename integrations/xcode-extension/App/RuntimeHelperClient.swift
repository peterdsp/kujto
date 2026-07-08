import Foundation
import ServiceManagement
import KujtoCore

/// XPC interface duplicated on the app side. Must match `Helper/main.swift`.
/// SMAppService offers no way to share Swift code between the two binaries,
/// so this is the single source of truth on the client side.
@objc protocol KujtoRuntimeXPC {
    // Observe
    func ping(reply: @escaping (String) -> Void)
    func listSimulators(reply: @escaping (Data?, String?) -> Void)
    func screenshot(udid: String, destinationPath: String, grantedCapability: String,
                    reply: @escaping (Data?, String?) -> Void)
    func logShow(udid: String, predicate: String, lastMinutes: Int, grantedCapability: String,
                 reply: @escaping (Data?, String?) -> Void)

    // Interact
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

    // Build
    func xcodebuild(arguments: [String], grantedCapability: String,
                    reply: @escaping (Data?, String?) -> Void)

    // Modify
    func eraseDevice(udid: String, grantedCapability: String,
                     reply: @escaping (Data?, String?) -> Void)
    func uninstall(udid: String, bundleID: String, grantedCapability: String,
                   reply: @escaping (Data?, String?) -> Void)
}

/// Manages the daemon lifecycle from the app side plus every RPC entry
/// point. Client-side safety checks run BEFORE the request even leaves the
/// wire; the helper double-checks server-side.
@MainActor
final class RuntimeHelperClient: ObservableObject {
    static let shared = RuntimeHelperClient()

    private static let daemonPlistName = "dev.peterdsp.kujto.runtime.plist"

    @Published private(set) var status: SMAppService.Status = .notFound
    @Published var grantedCapability: RuntimeCapability = .interact

    private var connection: NSXPCConnection?

    private init() {
        refreshStatus()
    }

    // MARK: Registration

    func refreshStatus() {
        status = SMAppService.daemon(plistName: Self.daemonPlistName).status
    }

    func register() throws {
        try SMAppService.daemon(plistName: Self.daemonPlistName).register()
        refreshStatus()
    }

    func unregister() async throws {
        try await SMAppService.daemon(plistName: Self.daemonPlistName).unregister()
        connection?.invalidate()
        connection = nil
        refreshStatus()
    }

    // MARK: Connection

    private func ensureConnection() -> NSXPCConnection {
        if let existing = connection { return existing }
        let conn = NSXPCConnection(machServiceName: "dev.peterdsp.kujto.runtime", options: [])
        conn.remoteObjectInterface = NSXPCInterface(with: KujtoRuntimeXPC.self)
        conn.invalidationHandler = { [weak self] in
            Task { @MainActor [weak self] in self?.connection = nil }
        }
        conn.resume()
        connection = conn
        return conn
    }

    private func proxy() throws -> KujtoRuntimeXPC {
        guard let p = ensureConnection().remoteObjectProxy as? KujtoRuntimeXPC else {
            throw HelperError.protocolMismatch
        }
        return p
    }

    // MARK: - Observe

    func ping() async -> Result<String, Error> {
        await withCheckedContinuation { cont in
            do {
                try proxy().ping { cont.resume(returning: .success($0)) }
            } catch { cont.resume(returning: .failure(error)) }
        }
    }

    func listSimulators() async -> Result<Data, Error> {
        await rpc { p, done in
            p.listSimulators { data, err in done(data, err) }
        }
    }

    func screenshot(udid: String, to destinationPath: String) async -> Result<Data, Error> {
        if let denial = clientGuard(.observe, path: destinationPath) { return .failure(denial) }
        return await rpc { p, done in
            p.screenshot(udid: udid, destinationPath: destinationPath,
                         grantedCapability: self.grantedCapability.rawValue) { d, e in done(d, e) }
        }
    }

    func logShow(udid: String, predicate: String = "", lastMinutes: Int = 2) async -> Result<Data, Error> {
        if let denial = clientGuard(.observe) { return .failure(denial) }
        return await rpc { p, done in
            p.logShow(udid: udid, predicate: predicate, lastMinutes: lastMinutes,
                      grantedCapability: self.grantedCapability.rawValue) { d, e in done(d, e) }
        }
    }

    // MARK: - Interact

    func boot(udid: String) async -> Result<Data, Error> {
        if let denial = clientGuard(.interact) { return .failure(denial) }
        return await rpc { p, done in
            p.boot(udid: udid, grantedCapability: self.grantedCapability.rawValue) { d, e in done(d, e) }
        }
    }

    func shutdown(udid: String) async -> Result<Data, Error> {
        if let denial = clientGuard(.interact) { return .failure(denial) }
        return await rpc { p, done in
            p.shutdown(udid: udid, grantedCapability: self.grantedCapability.rawValue) { d, e in done(d, e) }
        }
    }

    func launch(udid: String, bundleID: String) async -> Result<Data, Error> {
        if let denial = clientGuard(.interact, bundleID: bundleID) { return .failure(denial) }
        return await rpc { p, done in
            p.launch(udid: udid, bundleID: bundleID,
                     grantedCapability: self.grantedCapability.rawValue) { d, e in done(d, e) }
        }
    }

    func openURL(udid: String, url: String) async -> Result<Data, Error> {
        if let denial = clientGuard(.interact, path: url) { return .failure(denial) }
        return await rpc { p, done in
            p.openURL(udid: udid, url: url,
                      grantedCapability: self.grantedCapability.rawValue) { d, e in done(d, e) }
        }
    }

    func terminate(udid: String, bundleID: String) async -> Result<Data, Error> {
        if let denial = clientGuard(.interact, bundleID: bundleID) { return .failure(denial) }
        return await rpc { p, done in
            p.terminate(udid: udid, bundleID: bundleID,
                        grantedCapability: self.grantedCapability.rawValue) { d, e in done(d, e) }
        }
    }

    // MARK: - Build

    func xcodebuild(arguments: [String]) async -> Result<Data, Error> {
        if let denial = clientGuard(.build) { return .failure(denial) }
        for arg in arguments {
            if RuntimeNeverTouch.forbidsPath(arg) {
                return .failure(RuntimeSafetyError.forbiddenPath(arg))
            }
        }
        return await rpc { p, done in
            p.xcodebuild(arguments: arguments,
                         grantedCapability: self.grantedCapability.rawValue) { d, e in done(d, e) }
        }
    }

    // MARK: - Modify

    func eraseDevice(udid: String) async -> Result<Data, Error> {
        if RuntimeNeverTouch.pinnedProductionUDIDs.contains(udid) {
            return .failure(RuntimeSafetyError.forbiddenProductionDevice(udid))
        }
        if let denial = clientGuard(.modify) { return .failure(denial) }
        return await rpc { p, done in
            p.eraseDevice(udid: udid,
                          grantedCapability: self.grantedCapability.rawValue) { d, e in done(d, e) }
        }
    }

    func uninstall(udid: String, bundleID: String) async -> Result<Data, Error> {
        if let denial = clientGuard(.modify, bundleID: bundleID) { return .failure(denial) }
        return await rpc { p, done in
            p.uninstall(udid: udid, bundleID: bundleID,
                        grantedCapability: self.grantedCapability.rawValue) { d, e in done(d, e) }
        }
    }

    // MARK: - Safety

    private func clientGuard(
        _ required: RuntimeCapability,
        bundleID: String? = nil,
        path: String? = nil
    ) -> Error? {
        if grantedCapability < required {
            return RuntimeSafetyError.capabilityTooHigh(required: required, granted: grantedCapability)
        }
        if let bundleID, RuntimeNeverTouch.forbidsBundle(bundleID) {
            return RuntimeSafetyError.forbiddenBundle(bundleID)
        }
        if let path, RuntimeNeverTouch.forbidsPath(path) {
            return RuntimeSafetyError.forbiddenPath(path)
        }
        return nil
    }

    // MARK: - RPC plumbing

    private func rpc(
        _ call: @escaping (KujtoRuntimeXPC, @escaping (Data?, String?) -> Void) -> Void
    ) async -> Result<Data, Error> {
        await withCheckedContinuation { cont in
            do {
                let p = try proxy()
                call(p) { data, err in
                    if let err {
                        cont.resume(returning: .failure(HelperError.remote(err)))
                    } else if let data {
                        cont.resume(returning: .success(data))
                    } else {
                        cont.resume(returning: .success(Data()))
                    }
                }
            } catch {
                cont.resume(returning: .failure(error))
            }
        }
    }

    enum HelperError: LocalizedError {
        case protocolMismatch
        case remote(String)

        var errorDescription: String? {
            switch self {
            case .protocolMismatch: return "XPC proxy type mismatch. Rebuild the helper."
            case .remote(let msg):  return msg
            }
        }
    }
}

extension SMAppService.Status {
    var kujtoDescription: String {
        switch self {
        case .notRegistered:    return "Not registered yet"
        case .enabled:          return "Registered and running"
        case .requiresApproval: return "Waiting on your approval in System Settings"
        case .notFound:         return "Helper binary missing from the bundle"
        @unknown default:       return "Unknown"
        }
    }
}
