import Foundation

/// Composes Phase 3 of the case study: install + launch + (optional) log
/// streaming for a built `.app` on a booted simulator. Keeps state in the
/// shared `RuntimeStore` so `kujto apps` / `kujto stop` can find launched
/// apps later.
public final class AppLauncher {
    private let runner: ProcessRunner
    private let sim: SimulatorController
    private let emitter: EventEmitter
    private let store: RuntimeStore

    public init(
        runner: ProcessRunner = ProcessRunner(),
        sim: SimulatorController? = nil,
        emitter: EventEmitter,
        store: RuntimeStore = RuntimeStore()
    ) {
        self.runner = runner
        self.sim = sim ?? SimulatorController(runner: runner)
        self.emitter = emitter
        self.store = store
    }

    public struct LaunchOutcome {
        public let app: LaunchedApp
    }

    public func install(appPath: String, udid: String) throws {
        let r = try runner.run("xcrun", arguments: ["simctl", "install", udid, appPath])
        if r.exitCode != 0 {
            throw KujtoError(
                code: .appInstallFailed,
                message: LMsg(
                    sq: "Instalimi i \(appPath) deshtoi (\(r.exitCode))",
                    en: "Install of \(appPath) failed (\(r.exitCode))"
                )
            )
        }
        emitter.emit(type: "simulator_event", [
            "kind": .string("installed"),
            "udid": .string(udid),
            "app_path": .string(appPath)
        ])
    }

    public func launch(bundleId: String, udid: String) throws {
        let r = try runner.run("xcrun", arguments: ["simctl", "launch", udid, bundleId])
        if r.exitCode != 0 {
            throw KujtoError(
                code: .appLaunchFailed,
                message: LMsg(
                    sq: "Nisja e \(bundleId) deshtoi",
                    en: "Launch of \(bundleId) failed"
                )
            )
        }
        emitter.emit(type: "simulator_event", [
            "kind": .string("launched"),
            "udid": .string(udid),
            "bundle_id": .string(bundleId)
        ])
    }

    /// Full Phase 3 happy path. Caller is responsible for the build before
    /// this runs; we install, launch, persist to RuntimeStore, and return
    /// the record so logs / stop can target it.
    public func installAndLaunch(
        appPath: String,
        bundleId: String,
        processName: String,
        udid: String
    ) throws -> LaunchOutcome {
        // Best-effort boot; simctl boot returns non-zero if already booted,
        // which the controller treats as success.
        _ = try? sim.boot(udid: udid)
        try install(appPath: appPath, udid: udid)
        try launch(bundleId: bundleId, udid: udid)

        let app = LaunchedApp(
            id: AppLauncher.makeRunId(),
            bundleId: bundleId,
            processName: processName,
            simulatorUdid: udid,
            appPath: appPath,
            launchedAt: AppLauncher.isoNow(),
            logStreamPid: nil
        )
        try store.append(app)
        return LaunchOutcome(app: app)
    }

    public func terminate(bundleId: String, udid: String) throws {
        _ = try runner.run("xcrun", arguments: ["simctl", "terminate", udid, bundleId])
        emitter.emit(type: "simulator_event", [
            "kind": .string("terminated"),
            "udid": .string(udid),
            "bundle_id": .string(bundleId)
        ])
    }

    private static func makeRunId() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd_HHmmss"
        f.timeZone = TimeZone(identifier: "UTC")
        return "run_" + f.string(from: Date())
    }

    private static func isoNow() -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f.string(from: Date())
    }
}
