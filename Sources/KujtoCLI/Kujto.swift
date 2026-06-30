import ArgumentParser
import Foundation
import KujtoCore

/// Root command. Subcommands fall into three buckets:
///   1) Memory wiring (the original Kujto surface): wire, unwire, root
///   2) Apple toolchain orchestration (case study Phases 1–8):
///      context, config, build, run, test, logs, apps, stop, clean,
///      simulator, device, ui
struct Kujto: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "kujto",
        abstract: "Kujto - bilingual AI memory and Apple toolchain orchestrator",
        discussion: """
        Memorie AI dygjuhesh dhe orkestrator i veglave Apple.

        Memory commands:
          wire, unwire, root, rules, map, lint, agents

        Apple toolchain (Phase 1–8 of the case study):
          context, config, build, run, test, logs, apps, stop, clean,
          simulator, device, ui

        Set KUJTO_LANG=sq for Albanian output, KUJTO_LANG=en for English.
        """,
        version: "0.2.0",
        subcommands: [
            // Memory wiring (existing surface, preserved)
            WireCommand.self,
            UnwireCommand.self,
            RootCommand.self,
            RulesCommand.self,
            MapCommand.self,
            LintCommand.self,
            AgentsCommand.self,
            // Apple toolchain
            ContextCommand.self,
            ConfigCommand.self,
            BuildCommand.self,
            RunCommand.self,
            TestCommand.self,
            CleanCommand.self,
            LogsCommand.self,
            AppsCommand.self,
            StopCommand.self,
            SimulatorCommand.self,
            DeviceCommand.self,
            UICommand.self
        ]
    )
}

/// Shared options every Apple-toolchain subcommand inherits.
struct GlobalOptions: ParsableArguments {
    @Flag(name: .long, help: "Emit NDJSON events (machine-readable).")
    var json: Bool = false

    @Option(name: .long, help: "Path to a config file overriding .kujto/config.json.")
    var config: String?

    @Option(name: .long, help: "Hard timeout for the wrapped tool, in milliseconds.")
    var timeoutMs: Int?

    func makeEmitter() -> EventEmitter {
        EventEmitter(mode: json ? .ndjson : .human)
    }

    func loadConfig(at root: URL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)) throws -> KujtoConfig {
        if let configPath = config {
            let url = URL(fileURLWithPath: configPath)
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(KujtoConfig.self, from: data)
        }
        return try ConfigStore.load(at: root)
    }
}

/// Locates the Kujto package checkout. The original CLI used `#file` to walk
/// up three directories from `Sources/KujtoCLI/main.swift`. After splitting
/// into KujtoCore + Commands/, the math is the same depth, so we keep it.
/// `KUJTO_ROOT` env var overrides for distributed binaries.
enum KujtoRoot {
    static func locate() -> URL {
        if let env = ProcessInfo.processInfo.environment["KUJTO_ROOT"], !env.isEmpty {
            return URL(fileURLWithPath: env)
        }
        return URL(fileURLWithPath: #file)
            .deletingLastPathComponent()   // Sources/KujtoCLI/
            .deletingLastPathComponent()   // Sources/
            .deletingLastPathComponent()   // <repo root>
    }
}

/// Sugar for command bodies: catch any KujtoError, emit it through the
/// emitter, then exit with EX_SOFTWARE.
func runOrExit(_ emitter: EventEmitter, _ block: () throws -> Void) -> Never {
    do {
        try block()
        Foundation.exit(0)
    } catch let error as KujtoError {
        emitter.emitError(error)
        Foundation.exit(ExitCode.forKujtoError(error.code))
    } catch {
        emitter.emitError(KujtoError(
            code: .process,
            message: LMsg(
                sq: "Gabim i papritur: \(error.localizedDescription)",
                en: "Unexpected error: \(error.localizedDescription)"
            )
        ))
        Foundation.exit(ExitCode.internalError)
    }
}
