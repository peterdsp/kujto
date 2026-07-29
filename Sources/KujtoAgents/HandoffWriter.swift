import Foundation

/// What was true at the moment of a switch, captured so the account the user
/// moves to can pick the work up rather than starting cold.
public struct HandoffContext: Equatable, Sendable {
    public var repoName: String?
    public var branch: String?
    /// Repo-relative paths in play right now.
    public var changedFiles: [String]
    /// Rules that apply to those files, by title.
    public var activeRules: [String]
    /// Risk tags the current work carries.
    public var riskTags: [String]
    /// What the user (or the previous session) said the task is.
    public var task: String?
    /// Anything the previous account established that is not visible in the
    /// repo: decisions made, approaches ruled out.
    public var notes: [String]

    public init(repoName: String? = nil, branch: String? = nil, changedFiles: [String] = [],
                activeRules: [String] = [], riskTags: [String] = [], task: String? = nil,
                notes: [String] = []) {
        self.repoName = repoName
        self.branch = branch
        self.changedFiles = changedFiles
        self.activeRules = activeRules
        self.riskTags = riskTags
        self.task = task
        self.notes = notes
    }
}

/// Writes the handoff note that makes an account switch continuous instead of
/// amnesiac. This is the piece that only Kujto can do well: it already holds
/// the repo's rules, risks, and memory, so the note it writes is grounded in
/// the same source the next agent will read.
///
/// The note goes to `memory/handoff_active.md`, the location Kujto's own
/// AGENTS.md already tells every agent to read, so the next LLM picks it up
/// through the existing convention with no extra wiring.
public struct HandoffWriter: Sendable {
    /// Where the note lives inside a repo.
    public static let relativePath = "memory/handoff_active.md"

    public init() {}

    /// Renders the note. Pure, so the exact wording is unit tested and the UI
    /// can preview it before anything is written.
    public func render(from previous: AccountProfile?, to next: AccountProfile,
                       context: HandoffContext, timestamp: String) -> String {
        var out: [String] = []
        out.append("# Handoff")
        out.append("")
        out.append("Written when the active account changed. Read this before continuing;")
        out.append("it carries what the previous session established but the repo does not show.")
        out.append("")

        out.append("## Switch")
        let fromLabel = previous.map { "\($0.label) (\($0.vendor.rawValue), \($0.authMode.rawValue))" } ?? "none"
        out.append("- From: \(fromLabel)")
        out.append("- To: \(next.label) (\(next.vendor.rawValue), \(next.authMode.rawValue))")
        out.append("- When: \(timestamp)")
        out.append("")

        if context.repoName != nil || context.branch != nil {
            out.append("## Where")
            if let repo = context.repoName { out.append("- Repo: \(repo)") }
            if let branch = context.branch { out.append("- Branch: \(branch)") }
            out.append("")
        }

        if let task = context.task, !task.isEmpty {
            out.append("## Task in progress")
            out.append(task)
            out.append("")
        }

        if !context.changedFiles.isEmpty {
            out.append("## Files in play")
            for file in context.changedFiles.sorted() { out.append("- \(file)") }
            out.append("")
        }

        if !context.activeRules.isEmpty {
            out.append("## Rules that apply")
            for rule in context.activeRules.sorted() { out.append("- \(rule)") }
            out.append("")
        }

        if !context.riskTags.isEmpty {
            out.append("## Risk")
            out.append(context.riskTags.sorted().joined(separator: ", "))
            out.append("")
        }

        if !context.notes.isEmpty {
            out.append("## Established so far")
            for note in context.notes { out.append("- \(note)") }
            out.append("")
        }

        out.append("## Continuing")
        out.append("Read AGENTS.md and memory/MEMORY.md first, then the rules listed above.")
        out.append("Confirm the files in play still match before changing anything.")
        return out.joined(separator: "\n") + "\n"
    }

    /// Writes the note into `root`, creating the memory directory if needed.
    /// Returns the path written.
    @discardableResult
    public func write(from previous: AccountProfile?, to next: AccountProfile,
                      context: HandoffContext, timestamp: String, in root: URL) throws -> URL {
        let url = root.appendingPathComponent(Self.relativePath)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        let text = render(from: previous, to: next, context: context, timestamp: timestamp)
        try text.write(to: url, atomically: true, encoding: .utf8)
        return url
    }
}
