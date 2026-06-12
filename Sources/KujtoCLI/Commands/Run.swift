import ArgumentParser
import Foundation
import KujtoCore

struct RunCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "run",
        abstract: "Build, install, launch, and (optionally) stream logs."
    )

    @OptionGroup var global: GlobalOptions

    @Flag(name: .long, help: "Stream app logs after launch.")
    var log: Bool = false

    @Flag(name: .long, help: "Skip the build step (assume an existing .app).")
    var noBuild: Bool = false

    @Option(name: .long, help: "Override scheme.")
    var scheme: String?

    @Option(name: .long, help: "Override simulator name.")
    var simulator: String?

    @Option(name: .long, help: "Override simulator UDID.")
    var simulatorUdid: String?

    @Option(name: .long, help: "Override the .app path (skips build settings resolution).")
    var appPath: String?

    @Option(name: .long, help: "Override the bundle identifier.")
    var bundleId: String?

    /// Phase 3 happy path. We resolve the destination first because every
    /// other step needs the UDID, then either build → resolve .app, or use
    /// caller-provided paths so quick iterations don't pay the build cost.
    func run() {
        let emitter = global.makeEmitter()
        runOrExit(emitter) {
            var config = try global.loadConfig()
            if let scheme = scheme { config.scheme = scheme }
            if let simulator = simulator { config.simulatorName = simulator }
            if let simulatorUdid = simulatorUdid { config.simulatorUdid = simulatorUdid }

            let sim = SimulatorController()
            let udid = try sim.resolveUdid(name: config.simulatorName, udid: config.simulatorUdid)

            if !noBuild {
                let build = BuildRunner(emitter: emitter)
                let result = try build.build(config: config, simulatorUdid: udid, timeoutMs: global.timeoutMs)
                if !result.success {
                    Foundation.exit(ExitCode.failure)
                }
            }

            let resolvedApp: String
            let resolvedBundleId: String
            let resolvedProcess: String

            if let appPath = appPath, let bundleId = bundleId {
                resolvedApp = appPath
                resolvedBundleId = bundleId
                let info = try? readBundleInfo(at: appPath)
                resolvedProcess = info?.executable ?? (URL(fileURLWithPath: appPath).deletingPathExtension().lastPathComponent)
            } else {
                let settings = try BuildSettingsResolver().resolve(config: config, simulatorUdid: udid)
                resolvedApp = appPath ?? settings.appPath
                if let explicit = bundleId {
                    resolvedBundleId = explicit
                } else if let id = settings.productBundleIdentifier {
                    resolvedBundleId = id
                } else {
                    let info = try readBundleInfo(at: resolvedApp)
                    resolvedBundleId = info.bundleId
                }
                resolvedProcess = settings.executableName
                    ?? URL(fileURLWithPath: resolvedApp).deletingPathExtension().lastPathComponent
            }

            let launcher = AppLauncher(emitter: emitter)
            let outcome = try launcher.installAndLaunch(
                appPath: resolvedApp,
                bundleId: resolvedBundleId,
                processName: resolvedProcess,
                udid: udid
            )

            emitter.emit(type: "operation_finished", [
                "operation": .string("run"),
                "success": .bool(true),
                "app_id": .string(outcome.app.id),
                "bundle_id": .string(outcome.app.bundleId),
                "process": .string(outcome.app.processName),
                "udid": .string(outcome.app.simulatorUdid)
            ])

            if !global.json {
                print("✓ launched \(outcome.app.bundleId) (\(outcome.app.id))")
            }

            if log {
                let streamer = LogStreamer(emitter: emitter)
                try streamer.stream(
                    udid: udid,
                    processName: outcome.app.processName,
                    bundleId: outcome.app.bundleId,
                    customPredicate: nil,
                    timeoutMs: global.timeoutMs
                )
            }
        }
    }
}
