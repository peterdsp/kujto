import Foundation

/// The environment changes that activating a profile implies: variables to set,
/// and variables to clear because a previous account set them.
///
/// Producing a plan is pure and separate from applying it. That split is what
/// makes a one-tap switch safe to preview, diff, and test: the UI can show
/// exactly what will change before anything is written, and a wrong value is a
/// failing unit test rather than a broken shell.
public struct EnvironmentPlan: Equatable, Sendable {
    public var set: [String: String]
    public var unset: [String]

    public init(set: [String: String] = [:], unset: [String] = []) {
        self.set = set
        self.unset = unset
    }

    /// Shell lines that apply this plan, for the CLI and for an `env` file.
    /// Values are single-quoted so a value containing spaces survives.
    public func shellLines() -> [String] {
        var lines = unset.sorted().map { "unset \($0)" }
        for key in set.keys.sorted() {
            let value = (set[key] ?? "").replacingOccurrences(of: "'", with: "'\\''")
            lines.append("export \(key)='\(value)'")
        }
        return lines
    }
}

/// Builds the environment plan for a profile.
///
/// The variable names for cloud-hosted backends are deployment-facing and have
/// changed before, so they are read from a `VariableNames` value rather than
/// hardcoded at each call site. A wrong name is then one config change, not a
/// code change: the defaults below match the documented Claude Code variables.
public struct EnvironmentPlanner: Sendable {
    /// The variable names each backend uses. Override to track a rename or to
    /// support a vendor whose names differ.
    public struct VariableNames: Sendable {
        public var useVertex: String
        public var vertexProject: String
        public var vertexRegion: String
        public var useBedrock: String
        public var awsRegion: String
        public var apiKey: String

        public init(useVertex: String = "CLAUDE_CODE_USE_VERTEX",
                    vertexProject: String = "ANTHROPIC_VERTEX_PROJECT_ID",
                    vertexRegion: String = "CLOUD_ML_REGION",
                    useBedrock: String = "CLAUDE_CODE_USE_BEDROCK",
                    awsRegion: String = "AWS_REGION",
                    apiKey: String = "ANTHROPIC_API_KEY") {
            self.useVertex = useVertex
            self.vertexProject = vertexProject
            self.vertexRegion = vertexRegion
            self.useBedrock = useBedrock
            self.awsRegion = awsRegion
            self.apiKey = apiKey
        }

        /// Every variable this planner ever sets. Used to clear the previous
        /// account's routing so a switch never leaves a stale variable behind,
        /// which is the failure that silently bills the wrong account.
        public var all: [String] {
            [useVertex, vertexProject, vertexRegion, useBedrock, awsRegion, apiKey]
        }

        /// The Claude defaults.
        public static let claude = VariableNames()
    }

    private let names: VariableNames

    public init(names: VariableNames = .claude) {
        self.names = names
    }

    /// The plan for activating `profile`. Every variable the planner owns that
    /// this profile does not need is unset, so switching from Vertex back to a
    /// subscription genuinely leaves Vertex routing off.
    public func plan(for profile: AccountProfile) -> EnvironmentPlan {
        var set: [String: String] = [:]

        switch profile.authMode {
        case .subscription:
            // The credential is swapped in the Keychain, not the environment.
            break
        case .apiKey:
            // The value is injected by the applier from the Keychain; the plan
            // carries the name so a preview shows what will be set without
            // ever putting the secret in a plan.
            set[names.apiKey] = AccountSecretPlaceholder.value
        case .vertex:
            set[names.useVertex] = "1"
            set[names.vertexProject] = profile.settings["vertexProject"] ?? ""
            set[names.vertexRegion] = profile.settings["vertexRegion"] ?? ""
        case .bedrock:
            set[names.useBedrock] = "1"
            set[names.awsRegion] = profile.settings["awsRegion"] ?? ""
        }

        let unset = names.all.filter { set[$0] == nil }
        return EnvironmentPlan(set: set, unset: unset.sorted())
    }
}

/// Stands in for a secret inside a plan. A plan is displayable and testable, so
/// it must never carry a credential; the applier substitutes the real value
/// from the Keychain at write time.
public enum AccountSecretPlaceholder {
    public static let value = "<from-keychain>"

    public static func isPlaceholder(_ candidate: String) -> Bool {
        candidate == value
    }
}
