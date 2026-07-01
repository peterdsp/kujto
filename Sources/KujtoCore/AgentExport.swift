import Foundation

/// Read-side companion to `WireService`: given a target directory, report
/// which agent files are wired to this Kujto repo, which are foreign, and
/// which are missing. The Studio agent panel reads this; `kujto agents` prints
/// it. Same agent set as `WireService` so the round-trip stays consistent.
public enum AgentKind: String, CaseIterable, Sendable {
    case agents
    case claude
    case codex
    case gemini
    case cursor
    case copilot

    /// File path written into the target directory by `WireService`.
    /// Copilot lives inside `.github/`; the rest sit at the repo root.
    public var fileName: String {
        switch self {
        case .agents:  return "AGENTS.md"
        case .claude:  return "CLAUDE.md"
        case .codex:   return "CODEX.md"
        case .gemini:  return "GEMINI.md"
        case .cursor:  return ".cursorrules"
        case .copilot: return ".github/copilot-instructions.md"
        }
    }

    public var displayName: String {
        switch self {
        case .agents:  return "Generic (AGENTS.md)"
        case .claude:  return "Claude"
        case .codex:   return "Codex"
        case .gemini:  return "Gemini"
        case .cursor:  return "Cursor"
        case .copilot: return "GitHub Copilot"
        }
    }
}

public struct WireStatus: Sendable, Equatable {
    public enum State: String, Sendable {
        case notPresent = "not_present"
        case linked
        case foreign
    }

    public let agent: AgentKind
    public let state: State
    /// Symlink destination if the file is a symlink, else nil. Lets callers
    /// show "linked -> /path/to/AGENTS.md" without re-querying.
    public let linkDestination: String?

    public init(agent: AgentKind, state: State, linkDestination: String? = nil) {
        self.agent = agent
        self.state = state
        self.linkDestination = linkDestination
    }
}

public enum AgentExport {
    /// Inspects `target` for each agent file and reports its wire state.
    /// "linked" means the target file is a symlink that resolves to the same
    /// path as `<root>/AGENTS.md`; anything else under the same name counts
    /// as "foreign" so we never silently overwrite a user's own file.
    public static func status(target: URL, root: URL) -> [WireStatus] {
        let fm = FileManager.default
        let canonicalSource = root.appendingPathComponent("AGENTS.md")
            .resolvingSymlinksInPath().path

        return AgentKind.allCases.map { agent in
            let file = target.appendingPathComponent(agent.fileName)
            guard fm.fileExists(atPath: file.path) else {
                return WireStatus(agent: agent, state: .notPresent)
            }
            if let dest = try? fm.destinationOfSymbolicLink(atPath: file.path) {
                let resolved = (dest as NSString).isAbsolutePath
                    ? URL(fileURLWithPath: dest).resolvingSymlinksInPath().path
                    : target.appendingPathComponent(dest).resolvingSymlinksInPath().path
                let state: WireStatus.State = (resolved == canonicalSource) ? .linked : .foreign
                return WireStatus(agent: agent, state: state, linkDestination: dest)
            }
            return WireStatus(agent: agent, state: .foreign)
        }
    }
}
