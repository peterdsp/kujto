import Foundation

/// The git primitive layer for Kujto Studio. `KujtoGit` is deliberately thin
/// and pure: it knows nothing about memory, rules, or sync policy. It answers
/// "what is the state of this repo" and performs the six operations the git
/// panel and the sync loop need (status, diff, stage, commit, pull --rebase,
/// push).
///
/// The protocol exists so the backend can move from the shell (`ShellGitClient`,
/// today) to libgit2 (SwiftGit2 or a vendored xcframework) without touching a
/// single caller. That backend choice is an open question in the design doc,
/// resolved during this step based on notarization friction.

/// One entry from `git status`. Mirrors git's two-column model: an index
/// (staged) state and a worktree (unstaged) state, each drawn from the same
/// alphabet.
public struct GitChange: Equatable, Sendable {
    public enum State: Character, Sendable {
        case unmodified = " "
        case modified = "M"
        case added = "A"
        case deleted = "D"
        case renamed = "R"
        case copied = "C"
        case untracked = "?"
        case ignored = "!"
        case unmerged = "U"
        case typeChanged = "T"
    }

    /// Repo-relative path of the live file (the `new` side of a rename).
    public let path: String
    /// The `orig` side of a rename or copy, when the entry is one.
    public let originalPath: String?
    /// The staged column (git calls it X).
    public let index: State
    /// The unstaged column (git calls it Y).
    public let worktree: State

    public init(path: String, originalPath: String? = nil, index: State, worktree: State) {
        self.path = path
        self.originalPath = originalPath
        self.index = index
        self.worktree = worktree
    }

    /// True when there is something in the index to commit for this path.
    public var isStaged: Bool {
        switch index {
        case .unmodified, .untracked, .ignored: return false
        default: return true
        }
    }

    /// True when the file has a merge conflict (either column is unmerged).
    public var isConflicted: Bool {
        index == .unmerged || worktree == .unmerged
    }

    /// True for a path git is not tracking yet.
    public var isUntracked: Bool {
        index == .untracked || worktree == .untracked
    }
}

/// The result of `git status --porcelain --branch`: the branch, its upstream,
/// how far ahead and behind, and every changed path.
public struct GitStatus: Equatable, Sendable {
    /// Current branch name, or nil on a detached HEAD or an empty repo.
    public let branch: String?
    /// Upstream ref (for example `origin/main`), or nil when unset.
    public let upstream: String?
    /// Commits on the local branch not on upstream.
    public let ahead: Int
    /// Commits on upstream not on the local branch.
    public let behind: Int
    /// Every changed entry, staged and unstaged.
    public let changes: [GitChange]

    public init(branch: String?, upstream: String?, ahead: Int, behind: Int, changes: [GitChange]) {
        self.branch = branch
        self.upstream = upstream
        self.ahead = ahead
        self.behind = behind
        self.changes = changes
    }

    /// No changes in the working tree or index.
    public var isClean: Bool { changes.isEmpty }
    /// Any path is mid-merge-conflict.
    public var hasConflicts: Bool { changes.contains { $0.isConflicted } }
}

/// A single commit as read from `git log`.
public struct GitCommit: Equatable, Sendable {
    public let sha: String
    public let shortSha: String
    public let authorName: String
    public let authorEmail: String
    public let date: Date
    public let subject: String
    public let body: String

    public init(sha: String, shortSha: String, authorName: String, authorEmail: String, date: Date, subject: String, body: String) {
        self.sha = sha
        self.shortSha = shortSha
        self.authorName = authorName
        self.authorEmail = authorEmail
        self.date = date
        self.subject = subject
        self.body = body
    }
}

/// A per-file unified diff. For v1 the hunks are kept as the raw patch text so
/// the panel can render them; a structured hunk model can follow when the UI
/// needs per-line interaction.
public struct GitFileDiff: Equatable, Sendable {
    public let path: String
    public let patch: String

    public init(path: String, patch: String) {
        self.path = path
        self.patch = patch
    }
}

/// What happened when the sync loop ran `git pull --rebase`. The sync engine
/// switches on this: everything except `.conflicted` proceeds to push,
/// `.conflicted` pauses and raises the "keep both?" card.
public enum RebaseOutcome: Equatable, Sendable {
    /// Local already matched upstream; nothing to do.
    case upToDate
    /// Upstream had new commits; the working branch replayed cleanly on top.
    case rebased
    /// A rebase stopped on a real conflict. Carries the unmerged paths.
    case conflicted(files: [String])
}

/// The six operations the git panel and the sync loop need, plus repository
/// detection. Synchronous and throwing to match the existing `ProcessRunner`
/// idiom (see `KujtoCore.GitDiff`); `KujtoSync` calls these from a background
/// actor so the UI never blocks.
public protocol GitClient: Sendable {
    /// True when `url` is inside a git working tree.
    func isRepository(_ url: URL) -> Bool
    /// Clone `remote` into `destination` (which must not yet exist).
    func clone(_ remote: String, to destination: URL) throws
    /// The `origin` remote URL for `repo`, or nil when there is none.
    func remoteURL(in repo: URL) -> String?
    /// Repo-relative paths changed by commit `sha`. Handles the root commit.
    func changedFiles(inCommit sha: String, in repo: URL) throws -> [String]
    /// Stage resolved paths and continue an in-progress rebase.
    func rebaseContinue(in repo: URL) throws
    /// Abort an in-progress rebase, restoring the pre-rebase state.
    func rebaseAbort(in repo: URL) throws
    /// Full working-set status for `repo`.
    func status(in repo: URL) throws -> GitStatus
    /// Per-file diffs. `staged` selects `--cached`; `path` narrows to one file.
    func diff(in repo: URL, path: String?, staged: Bool) throws -> [GitFileDiff]
    /// Stage the given repo-relative paths (or everything when `paths` is empty).
    func stage(_ paths: [String], in repo: URL) throws
    /// Unstage the given repo-relative paths (or everything when `paths` is empty).
    func unstage(_ paths: [String], in repo: URL) throws
    /// Commit the staged index and return the commit that was created.
    func commit(message: String, in repo: URL) throws -> GitCommit
    /// Newest-first commit list, capped at `maxCount`.
    func log(in repo: URL, maxCount: Int) throws -> [GitCommit]
    /// `git pull --rebase`, classified into a `RebaseOutcome`.
    func pullRebase(in repo: URL) throws -> RebaseOutcome
    /// `git push` to the current branch's upstream.
    func push(in repo: URL) throws
}

public extension GitClient {
    /// Convenience: diff every changed file in the working tree.
    func diff(in repo: URL) throws -> [GitFileDiff] {
        try diff(in: repo, path: nil, staged: false)
    }
}
