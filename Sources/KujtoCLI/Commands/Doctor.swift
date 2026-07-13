import ArgumentParser
import Foundation
import KujtoCore

/// `kujto doctor`: environment health check for the Apple toolchain Kujto
/// drives (xcrun, xcodebuild, simulators, git). Exits non-zero when a
/// critical check fails so CI can gate on it.
struct DoctorCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "doctor",
        abstract: "Check that the Apple toolchain and simulators are ready."
    )

    @OptionGroup var global: GlobalOptions

    func run() {
        let emitter = global.makeEmitter()
        runOrExit(emitter) {
            let checks = Doctor.run()
            for check in checks {
                if global.json {
                    emitter.emit(type: "doctor_check", [
                        "name": .string(check.name),
                        "ok": .bool(check.ok),
                        "critical": .bool(check.critical),
                        "detail": check.detail.map { .string($0) } ?? .null
                    ])
                } else {
                    let mark = check.ok ? "✓" : (check.critical ? "✗" : "!")
                    var line = "\(mark) \(check.name)"
                    if let detail = check.detail { line += ": \(detail)" }
                    print(line)
                }
            }
            let healthy = Doctor.isHealthy(checks)
            if !global.json {
                print(healthy ? "\nAll critical checks passed." : "\nCritical checks failed.")
            }
            if !healthy { Foundation.exit(ExitCode.failure) }
        }
    }
}
