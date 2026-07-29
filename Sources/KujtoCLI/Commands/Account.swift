import ArgumentParser
import Foundation
import KujtoAgents
import KujtoCore

/// `kujto account` mirrors the app's account surface in the terminal, so a
/// switch is available wherever the user is working. Subcommands are the same
/// three verbs the UI offers: see them, use one, know where you are.
struct AccountCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "account",
        abstract: "List, switch, and inspect LLM accounts.",
        subcommands: [ListAccounts.self, UseAccount.self, AccountStatus.self],
        defaultSubcommand: ListAccounts.self
    )

    /// Shared paths so every subcommand agrees with the app about where things
    /// live.
    static var memoryDir: URL { AccountPaths.memoryDirectory() }

    static var envFile: URL { AccountPaths.environmentFile() }

    static func loadRoster() throws -> AccountRoster {
        try AccountRosterStore(repo: memoryDir).load()
    }

    /// One line per account, marking the active one.
    static func describe(_ profile: AccountProfile, active: Bool) -> String {
        let marker = active ? "*" : " "
        var line = "\(marker) \(profile.id)  \(profile.label)  [\(profile.vendor.rawValue)/\(profile.authMode.rawValue)]"
        if !profile.isReady {
            line += "  (missing: \(profile.missingSettings.joined(separator: ", ")))"
        }
        return line
    }
}

struct ListAccounts: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "list",
        abstract: "List every configured account."
    )

    @OptionGroup var global: GlobalOptions

    func run() throws {
        let roster = try AccountCommand.loadRoster()
        if global.json {
            global.makeEmitter().emit(type: "accounts", [
                "active": roster.activeID.map { .string($0) } ?? .null,
                "accounts": .array(roster.profiles.map { profile in
                    .object([
                        "id": .string(profile.id),
                        "label": .string(profile.label),
                        "vendor": .string(profile.vendor.rawValue),
                        "auth_mode": .string(profile.authMode.rawValue),
                        "ready": .bool(profile.isReady),
                    ])
                }),
            ])
        } else if roster.profiles.isEmpty {
            print("No accounts configured. Add one in Kujto Studio > Settings > Accounts.")
        } else {
            for profile in roster.profiles {
                print(AccountCommand.describe(profile, active: profile.id == roster.activeID))
            }
        }
    }
}

struct UseAccount: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "use",
        abstract: "Switch to an account and write the handoff note."
    )

    @OptionGroup var global: GlobalOptions

    @Argument(help: "The account id, or its label.")
    var account: String

    @Option(name: .long, help: "Repo to write the handoff note into. Defaults to the current directory.")
    var repo: String?

    func run() throws {
        var roster = try AccountCommand.loadRoster()
        // Accept a label as well as an id, because a label is what the user sees.
        let resolved = roster.profile(account)?.id
            ?? roster.profiles.first { $0.label.caseInsensitiveCompare(account) == .orderedSame }?.id
            ?? account

        let root = repo.map { URL(fileURLWithPath: $0) } ?? URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let switcher = AccountSwitcher(applier: FileEnvironmentApplier(url: AccountCommand.envFile))
        let outcome = try switcher.activate(
            resolved, in: &roster,
            context: HandoffContext(repoName: root.lastPathComponent),
            timestamp: ISO8601DateFormatter().string(from: Date()),
            handoffRoot: root)

        switch outcome {
        case let .switched(_, handoff):
            try AccountRosterStore(repo: AccountCommand.memoryDir).save(roster)
            if global.json {
                global.makeEmitter().emit(type: "account_switch", [
                    "status": .string("switched"),
                    "active": .string(resolved),
                    "handoff": handoff.map { .string($0) } ?? .null,
                ])
            } else {
                print("Switched to \(roster.active?.label ?? resolved).")
                print("Run: source \(AccountCommand.envFile.path)")
                if let handoff { print("Handoff written to \(handoff)") }
            }
        case .alreadyActive:
            print("Already on that account.")
        case let .incomplete(missing):
            print("Cannot switch: missing \(missing.joined(separator: ", ")).")
            Foundation.exit(1)
        case .unknownProfile:
            print("No account named \(account).")
            Foundation.exit(1)
        }
    }
}

struct AccountStatus: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "status",
        abstract: "Show the active account and where its requests go."
    )

    @OptionGroup var global: GlobalOptions

    func run() throws {
        let roster = try AccountCommand.loadRoster()
        guard let active = roster.active else {
            print("No active account.")
            Foundation.exit(1)
        }
        let plan = EnvironmentPlanner().plan(for: active)

        if global.json {
            global.makeEmitter().emit(type: "account_status", [
                "id": .string(active.id),
                "label": .string(active.label),
                "vendor": .string(active.vendor.rawValue),
                "auth_mode": .string(active.authMode.rawValue),
                "sets": .array(plan.set.keys.sorted().map { .string($0) }),
            ])
        } else {
            print("\(active.label)  [\(active.vendor.rawValue)/\(active.authMode.rawValue)]")
            for line in plan.shellLines() where line.hasPrefix("export") {
                // Never print a resolved secret; the plan carries a placeholder.
                print("  \(line)")
            }
        }
    }
}
