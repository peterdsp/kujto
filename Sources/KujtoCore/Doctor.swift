import Foundation

/// One line of the `kujto doctor` report. `critical` checks fail the command
/// (non-zero exit); non-critical ones are advisory.
public struct DoctorCheck: Sendable, Equatable {
    public let name: String
    public let ok: Bool
    public let critical: Bool
    public let detail: String?

    public init(name: String, ok: Bool, critical: Bool, detail: String? = nil) {
        self.name = name
        self.ok = ok
        self.critical = critical
        self.detail = detail
    }
}

/// Environment health check, the Swift-native counterpart to the skill's
/// `sim_health_check.sh`. Verifies the Apple toolchain pieces Kujto shells
/// out to (xcodebuild, simctl) plus git, and that at least one simulator is
/// available. The evaluation is factored out so it can be unit tested with
/// injected inputs instead of the real environment.
public enum Doctor {
    /// Pure evaluation. `toolExists` answers whether an executable resolves on
    /// `PATH`; `simulatorCount` is how many simulators `simctl` reported.
    public static func evaluate(
        toolExists: (String) -> Bool,
        simulatorCount: Int
    ) -> [DoctorCheck] {
        var checks: [DoctorCheck] = []

        let hasXcrun = toolExists("xcrun")
        checks.append(DoctorCheck(
            name: "xcrun",
            ok: hasXcrun,
            critical: true,
            detail: hasXcrun ? nil : "Install Xcode command line tools: xcode-select --install"
        ))

        let hasXcodebuild = toolExists("xcodebuild")
        checks.append(DoctorCheck(
            name: "xcodebuild",
            ok: hasXcodebuild,
            critical: true,
            detail: hasXcodebuild ? nil : "xcodebuild not found; open Xcode once and set the active developer directory."
        ))

        // simctl ships inside Xcode; if xcrun is present we treat its absence
        // as a soft warning rather than a hard failure.
        checks.append(DoctorCheck(
            name: "simulators",
            ok: simulatorCount > 0,
            critical: false,
            detail: simulatorCount > 0 ? "\(simulatorCount) available" : "No simulators available; add one via `kujto simulator create`."
        ))

        let hasGit = toolExists("git")
        checks.append(DoctorCheck(
            name: "git",
            ok: hasGit,
            critical: false,
            detail: hasGit ? nil : "git not found; risk/history commands need it."
        ))

        return checks
    }

    /// Runs the checks against the real environment.
    public static func run(sim: SimulatorController = SimulatorController()) -> [DoctorCheck] {
        let count = (try? sim.listDevices().count) ?? 0
        return evaluate(toolExists: Doctor.pathHasExecutable, simulatorCount: count)
    }

    /// `true` when `name` resolves to an executable on `PATH` or one of the
    /// usual Apple toolchain locations. Mirrors `ProcessRunner`'s resolution.
    public static func pathHasExecutable(_ name: String) -> Bool {
        let fm = FileManager.default
        if let path = ProcessInfo.processInfo.environment["PATH"] {
            for dir in path.split(separator: ":") {
                let url = URL(fileURLWithPath: String(dir)).appendingPathComponent(name)
                if fm.isExecutableFile(atPath: url.path) { return true }
            }
        }
        for fallback in ["/usr/bin/\(name)", "/usr/local/bin/\(name)", "/opt/homebrew/bin/\(name)"] {
            if fm.isExecutableFile(atPath: fallback) { return true }
        }
        return false
    }

    /// Overall pass = every critical check passed.
    public static func isHealthy(_ checks: [DoctorCheck]) -> Bool {
        !checks.contains { $0.critical && !$0.ok }
    }
}
