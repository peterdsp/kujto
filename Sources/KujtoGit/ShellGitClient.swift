import Foundation
import KujtoCore

/// The shell-backed `GitClient`: every operation is a `git` invocation through
/// `KujtoCore.ProcessRunner`, the same mechanism `GitDiff` already uses. Zero
/// native dependencies, App Store clean as long as a `git` binary is on PATH
/// (Xcode ships one). When we move to libgit2 this type is the only file that
/// changes; the protocol and every caller stay put.
public struct ShellGitClient: GitClient {
    private let runner: ProcessRunner
    /// Field separators for the log format. Unit separator between fields,
    /// record separator between commits; neither appears in commit text.
    private static let unit = "\u{1f}"
    private static let record = "\u{1e}"

    public init(runner: ProcessRunner = ProcessRunner()) {
        self.runner = runner
    }

    // MARK: Repository detection

    public func isRepository(_ url: URL) -> Bool {
        guard let result = try? runner.run(
            "git",
            arguments: ["-C", url.path, "rev-parse", "--is-inside-work-tree"]
        ) else { return false }
        return result.exitCode == 0 && result.stdout.trimmingCharacters(in: .whitespacesAndNewlines) == "true"
    }

    public func clone(_ remote: String, to destination: URL) throws {
        // git clone creates the leaf directory but not intermediate parents, so
        // ensure the parent exists, then clone to the full destination path.
        let parent = destination.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        let result: ProcessRunner.Result
        do {
            result = try runner.run("git", arguments: ["clone", remote, destination.path])
        } catch let error as KujtoError {
            throw error
        } catch {
            throw Self.error(.process, sq: "clone deshtoi: \(error.localizedDescription)",
                             en: "clone failed: \(error.localizedDescription)")
        }
        guard result.exitCode == 0 else {
            let detail = result.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            throw Self.error(.process, sq: "git clone doli me kod \(result.exitCode): \(detail)",
                             en: "git clone exited with code \(result.exitCode): \(detail)")
        }
    }

    public func remoteURL(in repo: URL) -> String? {
        guard let result = try? runner.run(
            "git",
            arguments: ["-C", repo.path, "remote", "get-url", "origin"]
        ), result.exitCode == 0 else { return nil }
        let url = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        return url.isEmpty ? nil : url
    }

    // MARK: Status

    public func status(in repo: URL) throws -> GitStatus {
        let result = try git(["status", "--porcelain", "--branch", "--untracked-files=all"], in: repo)
        return Self.parseStatus(result.stdout)
    }

    /// Parses `git status --porcelain --branch`. The first line is the branch
    /// header (`## name...upstream [ahead N, behind M]`); the rest are `XY path`
    /// entries. Kept `static` and pure so it can be unit tested without a repo.
    static func parseStatus(_ output: String) -> GitStatus {
        var branch: String?
        var upstream: String?
        var ahead = 0
        var behind = 0
        var changes: [GitChange] = []

        for rawLine in output.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = String(rawLine)
            if line.isEmpty { continue }

            if line.hasPrefix("## ") {
                (branch, upstream, ahead, behind) = parseBranchHeader(String(line.dropFirst(3)))
                continue
            }
            if let change = parseChange(line) {
                changes.append(change)
            }
        }
        return GitStatus(branch: branch, upstream: upstream, ahead: ahead, behind: behind, changes: changes)
    }

    /// Parses the `## ...` header body. Handles `name...upstream`, a bare
    /// `name`, the `No commits yet on name` empty-repo form, and an optional
    /// `[ahead N, behind M]` suffix.
    static func parseBranchHeader(_ body: String) -> (String?, String?, Int, Int) {
        var work = body
        var ahead = 0
        var behind = 0

        if let bracket = work.range(of: " [") {
            let tracking = String(work[work.index(after: bracket.lowerBound)...]) // includes leading '['
            work = String(work[..<bracket.lowerBound])
            ahead = extractCount("ahead", from: tracking)
            behind = extractCount("behind", from: tracking)
        }

        // Empty repo: "No commits yet on main".
        if let onRange = work.range(of: "No commits yet on ") {
            let name = String(work[onRange.upperBound...]).trimmingCharacters(in: .whitespaces)
            return (name.isEmpty ? nil : name, nil, ahead, behind)
        }

        if let sep = work.range(of: "...") {
            let name = String(work[..<sep.lowerBound])
            let up = String(work[sep.upperBound...])
            return (name.isEmpty ? nil : name, up.isEmpty ? nil : up, ahead, behind)
        }

        let name = work.trimmingCharacters(in: .whitespaces)
        return (name.isEmpty ? nil : name, nil, ahead, behind)
    }

    private static func extractCount(_ label: String, from tracking: String) -> Int {
        guard let range = tracking.range(of: "\(label) ") else { return 0 }
        let rest = tracking[range.upperBound...]
        let digits = rest.prefix { $0.isNumber }
        return Int(digits) ?? 0
    }

    /// Parses one `XY path` porcelain entry into a `GitChange`.
    static func parseChange(_ line: String) -> GitChange? {
        guard line.count >= 4 else { return nil }
        let chars = Array(line)
        let indexState = GitChange.State(rawValue: chars[0]) ?? .unmodified
        let worktreeState = GitChange.State(rawValue: chars[1]) ?? .unmodified
        // chars[2] is the separating space.
        var path = String(chars[3...])
        var original: String?

        if let arrow = path.range(of: " -> ") {
            original = unquote(String(path[..<arrow.lowerBound]))
            path = String(path[arrow.upperBound...])
        }
        path = unquote(path)
        guard !path.isEmpty else { return nil }
        return GitChange(path: path, originalPath: original, index: indexState, worktree: worktreeState)
    }

    /// Strips one surrounding pair of double quotes git adds around paths with
    /// unusual characters. Mirrors `KujtoCore.GitDiff.unquote`.
    private static func unquote(_ s: String) -> String {
        guard s.count >= 2, s.hasPrefix("\""), s.hasSuffix("\"") else { return s }
        return String(s.dropFirst().dropLast())
    }

    // MARK: Diff

    public func diff(in repo: URL, path: String?, staged: Bool) throws -> [GitFileDiff] {
        var args = ["diff"]
        if staged { args.append("--cached") }
        if let path = path { args.append(contentsOf: ["--", path]) }
        let result = try git(args, in: repo)
        return Self.splitPatches(result.stdout)
    }

    /// Splits a multi-file unified diff into one `GitFileDiff` per file, keyed
    /// on the `b/` path from each `diff --git a/... b/...` header.
    static func splitPatches(_ output: String) -> [GitFileDiff] {
        guard !output.isEmpty else { return [] }
        var diffs: [GitFileDiff] = []
        var currentPath: String?
        var currentLines: [String] = []

        func flush() {
            if let path = currentPath, !currentLines.isEmpty {
                diffs.append(GitFileDiff(path: path, patch: currentLines.joined(separator: "\n")))
            }
        }

        for rawLine in output.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = String(rawLine)
            if line.hasPrefix("diff --git ") {
                flush()
                currentLines = [line]
                currentPath = parseDiffHeaderPath(line)
            } else if currentPath != nil {
                currentLines.append(line)
            }
        }
        flush()
        return diffs
    }

    /// Pulls the `b/` path out of a `diff --git a/x b/x` header.
    private static func parseDiffHeaderPath(_ header: String) -> String? {
        guard let bRange = header.range(of: " b/") else { return nil }
        return String(header[bRange.upperBound...])
    }

    // MARK: Stage / unstage

    public func stage(_ paths: [String], in repo: URL) throws {
        var args = ["add", "--all"]
        if !paths.isEmpty { args = ["add", "--"] + paths }
        _ = try git(args, in: repo)
    }

    public func unstage(_ paths: [String], in repo: URL) throws {
        var args = ["reset", "--quiet", "HEAD"]
        if !paths.isEmpty { args.append(contentsOf: ["--"] + paths) }
        _ = try git(args, in: repo)
    }

    // MARK: Commit

    public func commit(message: String, in repo: URL) throws -> GitCommit {
        _ = try git(["commit", "--message", message], in: repo)
        guard let head = try log(in: repo, maxCount: 1).first else {
            throw Self.error(.process, sq: "Commit u krijua por HEAD nuk u lexua",
                             en: "Commit created but HEAD could not be read")
        }
        return head
    }

    // MARK: Log

    public func log(in repo: URL, maxCount: Int) throws -> [GitCommit] {
        let format = ["%H", "%h", "%an", "%ae", "%aI", "%s", "%b"].joined(separator: Self.unit) + Self.record
        let result = try git(["log", "--max-count=\(maxCount)", "--pretty=format:\(format)"], in: repo)
        return Self.parseLog(result.stdout)
    }

    /// Parses the record-separated log format into commits.
    static func parseLog(_ output: String) -> [GitCommit] {
        var commits: [GitCommit] = []
        let iso = ISO8601DateFormatter()
        for rawRecord in output.components(separatedBy: record) {
            let record = rawRecord.trimmingCharacters(in: .whitespacesAndNewlines)
            if record.isEmpty { continue }
            let fields = record.components(separatedBy: unit)
            guard fields.count >= 7 else { continue }
            commits.append(GitCommit(
                sha: fields[0],
                shortSha: fields[1],
                authorName: fields[2],
                authorEmail: fields[3],
                date: iso.date(from: fields[4]) ?? Date(timeIntervalSince1970: 0),
                subject: fields[5],
                body: fields[6].trimmingCharacters(in: .whitespacesAndNewlines)
            ))
        }
        return commits
    }

    // MARK: Pull (rebase) and push

    public func pullRebase(in repo: URL) throws -> RebaseOutcome {
        let result = try? git(["pull", "--rebase"], in: repo)
        // A clean pull exits 0. A conflict exits non-zero and leaves unmerged
        // paths behind; we surface those rather than the raw git text.
        if let result = result, result.exitCode == 0 {
            let combined = result.stdout + result.stderr
            if combined.contains("Already up to date") || combined.contains("up to date") {
                return .upToDate
            }
            return .rebased
        }
        let unmerged = (try? unmergedPaths(in: repo)) ?? []
        if !unmerged.isEmpty {
            return .conflicted(files: unmerged)
        }
        // Non-zero exit with no unmerged paths is a real failure, not a merge
        // the user can resolve. Surface it.
        throw Self.error(.process, sq: "pull --rebase deshtoi", en: "pull --rebase failed")
    }

    public func push(in repo: URL) throws {
        let result = try? git(["push"], in: repo)
        guard let result = result else {
            throw Self.error(.process, sq: "push nuk u ekzekutua", en: "push could not run")
        }
        if result.exitCode == 0 { return }
        let combined = (result.stdout + result.stderr).lowercased()
        if combined.contains("non-fast-forward") || combined.contains("rejected") {
            throw Self.error(.process,
                             sq: "push u refuzua: remote-i ka commit te rinj, bej pull --rebase",
                             en: "push rejected: remote has new commits, pull --rebase first")
        }
        throw Self.error(.process, sq: "push deshtoi", en: "push failed")
    }

    /// Paths git reports as unmerged (`--diff-filter=U`) after a stopped rebase.
    private func unmergedPaths(in repo: URL) throws -> [String] {
        let result = try git(["diff", "--name-only", "--diff-filter=U"], in: repo)
        return result.stdout
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map { String($0).trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    // MARK: Plumbing

    /// Runs `git -C <repo> <args>` and throws a typed `KujtoError` on failure.
    @discardableResult
    private func git(_ arguments: [String], in repo: URL) throws -> ProcessRunner.Result {
        let full = ["-C", repo.path] + arguments
        let result: ProcessRunner.Result
        do {
            result = try runner.run("git", arguments: full)
        } catch let error as KujtoError {
            throw error
        } catch {
            throw Self.error(.process, sq: "git deshtoi: \(error.localizedDescription)",
                             en: "git failed: \(error.localizedDescription)")
        }
        guard result.exitCode == 0 else {
            let detail = result.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            throw Self.error(.process,
                             sq: "git \(arguments.first ?? "") doli me kod \(result.exitCode): \(detail)",
                             en: "git \(arguments.first ?? "") exited with code \(result.exitCode): \(detail)")
        }
        return result
    }

    private static func error(_ code: KujtoError.Code, sq: String, en: String) -> KujtoError {
        KujtoError(code: code, message: LMsg(sq: sq, en: en))
    }
}
