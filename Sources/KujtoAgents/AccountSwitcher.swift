import Foundation

/// What a switch did, or why it did nothing.
public enum SwitchOutcome: Equatable, Sendable {
    /// Switched. Carries the plan applied and where the handoff note was written.
    case switched(plan: EnvironmentPlan, handoffPath: String?)
    /// Already on this account; nothing to do.
    case alreadyActive
    /// The profile is missing routing values it needs. Carries the setting names.
    case incomplete(missing: [String])
    /// The profile id is not in the roster.
    case unknownProfile
}

/// Persists the environment side of a switch. Injected so the engine is
/// testable and so the app, the CLI, and a future shell integration can each
/// apply the change the way their surface requires.
public protocol EnvironmentApplier: Sendable {
    /// Applies a plan. `secretProvider` resolves a profile's credential from
    /// the Keychain, and is called only for values the plan marks as secret,
    /// so a credential is read at the last possible moment and never stored in
    /// the plan itself.
    func apply(_ plan: EnvironmentPlan, secret: @Sendable () -> String?) throws
}

/// Writes the plan to a shell-sourceable file. The file is the integration
/// point: a shell hook sources it, so a switch in the app reaches the terminal
/// without Kujto having to reach into a running shell.
public struct FileEnvironmentApplier: EnvironmentApplier {
    private let url: URL

    public init(url: URL) {
        self.url = url
    }

    public func apply(_ plan: EnvironmentPlan, secret: @Sendable () -> String?) throws {
        var resolved = plan
        for (key, value) in plan.set where AccountSecretPlaceholder.isPlaceholder(value) {
            guard let real = secret() else {
                throw AccountError.missingCredential(key)
            }
            resolved.set[key] = real
        }
        let body = ([
            "# Written by Kujto. Sourced by your shell; do not edit by hand.",
        ] + resolved.shellLines()).joined(separator: "\n") + "\n"

        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        try body.write(to: url, atomically: true, encoding: .utf8)
        // The file can carry a credential, so keep it owner-only.
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }
}

public enum AccountError: Error, Equatable, Sendable {
    case missingCredential(String)
}

/// Performs the switch: validate, plan, apply, write the handoff, record the
/// new active account. Every step is ordered so a failure leaves the roster
/// untouched rather than pointing at an account that was never activated.
public struct AccountSwitcher: Sendable {
    private let planner: EnvironmentPlanner
    private let applier: EnvironmentApplier
    private let handoff: HandoffWriter

    public init(planner: EnvironmentPlanner = EnvironmentPlanner(),
                applier: EnvironmentApplier,
                handoff: HandoffWriter = HandoffWriter()) {
        self.planner = planner
        self.applier = applier
        self.handoff = handoff
    }

    /// Switches `roster` to `id`.
    ///
    /// `handoffRoot` is the repo the note is written into; pass nil to skip the
    /// note. `secret` resolves the target profile's credential. The roster is
    /// mutated only after the environment is applied, so a failed apply never
    /// leaves the roster claiming an account that is not active.
    public func activate(_ id: String, in roster: inout AccountRoster,
                         context: HandoffContext = HandoffContext(),
                         timestamp: String,
                         handoffRoot: URL? = nil,
                         secret: @Sendable @escaping () -> String? = { nil }) throws -> SwitchOutcome {
        guard let target = roster.profile(id) else { return .unknownProfile }
        guard target.isReady else { return .incomplete(missing: target.missingSettings) }
        if roster.activeID == id { return .alreadyActive }

        let previous = roster.active
        let plan = planner.plan(for: target)
        try applier.apply(plan, secret: secret)

        var handoffPath: String?
        if let root = handoffRoot {
            let url = try handoff.write(from: previous, to: target, context: context,
                                        timestamp: timestamp, in: root)
            handoffPath = url.path
        }

        roster.activeID = id
        return .switched(plan: plan, handoffPath: handoffPath)
    }
}
