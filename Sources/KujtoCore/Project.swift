import Foundation

/// Result of `xcodebuild -list -json` for a workspace or project.
public struct XcodeListOutput: Codable, Sendable {
    public let workspace: WorkspaceInfo?
    public let project: ProjectInfo?

    public struct WorkspaceInfo: Codable, Sendable {
        public let name: String
        public let schemes: [String]
    }

    public struct ProjectInfo: Codable, Sendable {
        public let name: String
        public let schemes: [String]
        public let targets: [String]
        public let configurations: [String]
    }
}

public struct DiscoveryReport: Sendable {
    public let workspaces: [String]
    public let projects: [String]
    public let schemes: [String]
    public let configurations: [String]
    public let cwd: String
}

public final class ProjectDiscovery {
    private let runner: ProcessRunner

    public init(runner: ProcessRunner = ProcessRunner()) {
        self.runner = runner
    }

    /// Walks the working directory for `*.xcworkspace` / `*.xcodeproj` and
    /// asks xcodebuild for schemes when one is found.
    public func discover(at root: URL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)) throws -> DiscoveryReport {
        let fm = FileManager.default
        let contents = (try? fm.contentsOfDirectory(atPath: root.path)) ?? []
        let workspaces = contents.filter { $0.hasSuffix(".xcworkspace") }
        let projects = contents.filter { $0.hasSuffix(".xcodeproj") }

        var schemes: [String] = []
        var configurations: [String] = []

        if let workspace = workspaces.first {
            let info = try? runner.runJSON(
                "xcodebuild",
                arguments: ["-list", "-json", "-workspace", workspace],
                type: XcodeListOutput.self
            )
            if let ws = info?.workspace {
                schemes = ws.schemes
            } else if let p = info?.project {
                schemes = p.schemes
                configurations = p.configurations
            }
        } else if let project = projects.first {
            let info = try? runner.runJSON(
                "xcodebuild",
                arguments: ["-list", "-json", "-project", project],
                type: XcodeListOutput.self
            )
            if let p = info?.project {
                schemes = p.schemes
                configurations = p.configurations
            }
        }

        return DiscoveryReport(
            workspaces: workspaces,
            projects: projects,
            schemes: schemes,
            configurations: configurations,
            cwd: root.path
        )
    }
}
