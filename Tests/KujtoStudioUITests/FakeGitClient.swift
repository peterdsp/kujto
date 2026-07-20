import Foundation
import KujtoGit

/// A configurable in-memory GitClient for view-model tests. Records the calls
/// the panel makes and returns a scriptable status, so no real repo is needed.
final class FakeGitClient: GitClient, @unchecked Sendable {
    private let lock = NSLock()
    private var _status: GitStatus
    private(set) var committedMessages: [String] = []
    private(set) var stagedCalls: [[String]] = []
    private(set) var unstagedCalls: [[String]] = []

    init(status: GitStatus) {
        self._status = status
    }

    func setStatus(_ status: GitStatus) {
        lock.lock(); _status = status; lock.unlock()
    }

    /// Files a given commit touched, scriptable per sha for history tests.
    var changedFilesByCommit: [String: [String]] = [:]

    func isRepository(_ url: URL) -> Bool { true }
    func clone(_ remote: String, to destination: URL) throws {}
    func remoteURL(in repo: URL) -> String? { nil }
    func changedFiles(inCommit sha: String, in repo: URL) throws -> [String] {
        lock.lock(); defer { lock.unlock() }
        return changedFilesByCommit[sha] ?? []
    }

    func status(in repo: URL) throws -> GitStatus {
        lock.lock(); defer { lock.unlock() }
        return _status
    }

    func diff(in repo: URL, path: String?, staged: Bool) throws -> [GitFileDiff] { [] }

    func stage(_ paths: [String], in repo: URL) throws {
        lock.lock(); stagedCalls.append(paths); lock.unlock()
    }

    func unstage(_ paths: [String], in repo: URL) throws {
        lock.lock(); unstagedCalls.append(paths); lock.unlock()
    }

    func commit(message: String, in repo: URL) throws -> GitCommit {
        lock.lock()
        committedMessages.append(message)
        // After a commit the tree is clean.
        _status = GitStatus(branch: _status.branch, upstream: _status.upstream,
                            ahead: _status.ahead + 1, behind: _status.behind, changes: [])
        lock.unlock()
        return GitCommit(sha: "0", shortSha: "0", authorName: "T", authorEmail: "t@x",
                         date: Date(timeIntervalSince1970: 0), subject: message, body: "")
    }

    func log(in repo: URL, maxCount: Int) throws -> [GitCommit] { [] }
    func pullRebase(in repo: URL) throws -> RebaseOutcome { .upToDate }
    func push(in repo: URL) throws {}
}
