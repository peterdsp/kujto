import Foundation
import Combine
import KujtoGit
import KujtoSync

/// The view-model behind the git panel. It turns a `GitClient` and a repo into
/// observable panel state: the staged and unstaged rows, the branch, the commit
/// message, and the sync status glyph. All git work runs off the main actor so
/// the panel never blocks; results are applied on the main actor.
///
/// This is the seam the step-3 rules fusion plugs into: when `staged` changes,
/// a rules resolver can annotate each row. Kept free of SwiftUI so it is unit
/// testable with a fake client.
@MainActor
public final class GitPanelModel: ObservableObject {
    @Published public private(set) var branch: String?
    @Published public private(set) var staged: [GitChange] = []
    @Published public private(set) var unstaged: [GitChange] = []
    @Published public var commitMessage: String = ""
    @Published public private(set) var syncStatus: SyncStatus = .idle
    @Published public var theme: Theme
    /// The rules-in-commit strip for the currently staged set. Nil when no
    /// inspector is configured.
    @Published public private(set) var inspection: CommitInspection?

    private let client: GitClient
    private let repo: URL
    private let inspector: CommitInspector?

    public init(repo: URL, client: GitClient = ShellGitClient(),
                theme: Theme = Themes.default, inspector: CommitInspector? = nil) {
        self.repo = repo
        self.client = client
        self.theme = theme
        self.inspector = inspector
    }

    /// Commit is allowed only with something staged and a non-empty message.
    public var canCommit: Bool {
        !staged.isEmpty && !commitMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Reloads status and re-splits the rows.
    public func refresh() async throws {
        let status = try await offMain { [client, repo] in try client.status(in: repo) }
        apply(status)
    }

    /// Stages one change, or everything when `change` is nil.
    public func stage(_ change: GitChange? = nil) async throws {
        let paths = change.map { [$0.path] } ?? []
        try await offMain { [client, repo] in try client.stage(paths, in: repo) }
        try await refresh()
    }

    /// Unstages one change, or everything when `change` is nil.
    public func unstage(_ change: GitChange? = nil) async throws {
        let paths = change.map { [$0.path] } ?? []
        try await offMain { [client, repo] in try client.unstage(paths, in: repo) }
        try await refresh()
    }

    /// Commits the staged index with the current message, then clears it and
    /// refreshes. A no-op when `canCommit` is false.
    public func commit() async throws {
        guard canCommit else { return }
        let message = commitMessage
        _ = try await offMain { [client, repo] in try client.commit(message: message, in: repo) }
        commitMessage = ""
        try await refresh()
    }

    /// Lets an owner (the app, driven by the sync coordinator) push status into
    /// the panel's glyph.
    public func setSyncStatus(_ status: SyncStatus) {
        syncStatus = status
    }

    // MARK: Internals

    private func apply(_ status: GitStatus) {
        branch = status.branch
        staged = status.changes.filter { $0.isStaged }
        unstaged = status.changes.filter { !$0.isStaged }
        // The fusion: re-resolve rules for the staged set on every change.
        inspection = inspector.map { $0.inspect(staged: staged) }
    }

    /// Runs blocking git work off the main actor and returns to it with the
    /// result.
    private func offMain<T: Sendable>(_ work: @escaping @Sendable () throws -> T) async throws -> T {
        try await Task.detached(priority: .userInitiated) { try work() }.value
    }
}
