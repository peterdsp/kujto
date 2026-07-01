import AppIntents
import Foundation
import KujtoCore

/// App Intents that surface Kujto's memory in Shortcuts, Spotlight, and Siri.
/// Every intent takes the last-picked repo from `SharedConfig` so users do not
/// have to configure the path each time.
///
/// Available intents:
///   - Show Rules for File (input: file path or URL)
///   - Summarize Repo Rules  (input: optional repo path)
///   - Lint Memory           (input: optional repo path)
///   - Prepare Agent Context (input: file path, returns a paste-ready string)

struct ShowRulesForFileIntent: AppIntent {
    static var title: LocalizedStringResource = "Show Rules for File"
    static var description = IntentDescription(
        "Returns the memory rules that apply to a file, ranked by glob specificity."
    )
    static var openAppWhenRun: Bool = false

    @Parameter(title: "File", description: "The path to the file you are about to edit.")
    var filePath: String

    func perform() async throws -> some IntentResult & ReturnsValue<[String]> {
        let index = try loadRuleIndex()
        let repoRoot = try repoRoot()
        let relative = relativePath(filePath, to: repoRoot)
        let matches = index.resolve(file: relative)
        let lines = matches.map { m in
            let risk = m.rule.risk.isEmpty ? "" : "  [risk: \(m.rule.risk.joined(separator: ", "))]"
            return "\(m.rule.title)\(risk) — \(m.rule.path) (matched \(m.glob))"
        }
        return .result(value: lines.isEmpty ? ["No file-scoped rules match."] : lines)
    }
}

struct SummarizeRepoRulesIntent: AppIntent {
    static var title: LocalizedStringResource = "Summarize Repo Rules"
    static var description = IntentDescription(
        "One-line summary of the memory map: scoped rules, base memory, risk tags."
    )

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let map = try MemoryMapScanner.scan(root: try repoRoot())
        let risks = map.riskTags.isEmpty ? "none" : map.riskTags.joined(separator: ", ")
        let summary = """
        \(map.scopedRules.count) scoped rules · \(map.baseRules.count) base memory files · \
        \(map.skillCount) skills · risk tags: \(risks)
        """
        return .result(value: summary)
    }
}

struct LintMemoryIntent: AppIntent {
    static var title: LocalizedStringResource = "Lint Memory"
    static var description = IntentDescription(
        "Runs the Kujto memory linter and returns each finding as a line."
    )

    func perform() async throws -> some IntentResult & ReturnsValue<[String]> {
        let issues = try MemoryLinter.lint(root: try repoRoot())
        if issues.isEmpty { return .result(value: ["Lint clean."]) }
        return .result(value: issues.map { i in
            "[\(i.severity.rawValue)] \(i.file): \(i.message)  (\(i.code))"
        })
    }
}

struct PrepareAgentContextIntent: AppIntent {
    static var title: LocalizedStringResource = "Prepare Agent Context"
    static var description = IntentDescription(
        "Renders the rules for a file as a prompt block you can paste into an agent."
    )

    @Parameter(title: "File", description: "The path to the file you are about to edit.")
    var filePath: String

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let index = try loadRuleIndex()
        let repoRoot = try repoRoot()
        let relative = relativePath(filePath, to: repoRoot)
        let matches = index.resolve(file: relative)
        var lines = ["Rules for \(relative):"]
        for m in matches {
            lines.append("- \(m.rule.title) (\(m.rule.path))")
        }
        if matches.isEmpty { lines.append("- (base memory only)") }
        return .result(value: lines.joined(separator: "\n"))
    }
}

/// Exposes the intents to Shortcuts as a discoverable set.
struct KujtoShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: ShowRulesForFileIntent(),
            phrases: [
                "Show \(.applicationName) rules",
                "Ask \(.applicationName) for the rules"
            ],
            shortTitle: "Show Rules",
            systemImageName: "shield.checkerboard"
        )
        AppShortcut(
            intent: SummarizeRepoRulesIntent(),
            phrases: [
                "Summarize \(.applicationName) rules",
                "Summarize the \(.applicationName) memory map"
            ],
            shortTitle: "Summarize Rules",
            systemImageName: "map"
        )
        AppShortcut(
            intent: LintMemoryIntent(),
            phrases: [
                "Lint the \(.applicationName) memory",
                "Run \(.applicationName) memory lint"
            ],
            shortTitle: "Lint Memory",
            systemImageName: "checkmark.shield"
        )
        AppShortcut(
            intent: PrepareAgentContextIntent(),
            phrases: [
                "Prepare \(.applicationName) agent context",
                "Get \(.applicationName) prompt"
            ],
            shortTitle: "Agent Context",
            systemImageName: "wand.and.stars"
        )
    }
}

// MARK: - Shared helpers

private func repoRoot() throws -> URL {
    if let url = SharedConfig.resolveRoot() {
        // The caller must stop accessing the security-scoped resource;
        // App Intents live for the duration of the call, so returning
        // without stopping is fine here.
        return url
    }
    throw KujtoIntentError.noRepoConfigured
}

private func loadRuleIndex() throws -> RuleIndex {
    try RuleIndex.load(root: try repoRoot())
}

private func relativePath(_ raw: String, to root: URL) -> String {
    let normalized = raw.hasPrefix("file://") ? URL(string: raw)?.path ?? raw : raw
    let rootPath = root.resolvingSymlinksInPath().path
    return normalized.hasPrefix(rootPath + "/")
        ? String(normalized.dropFirst(rootPath.count + 1))
        : normalized
}

enum KujtoIntentError: LocalizedError {
    case noRepoConfigured
    var errorDescription: String? {
        switch self {
        case .noRepoConfigured: return "Open Kujto Studio, choose a repo, then try again."
        }
    }
}
