import Foundation

/// The diff source for predictive governance. Answers "which files are in play
/// right now" so the risk scorer can weight a file that is being edited before
/// the change lands, not just a file that happens to match a risky rule.
///
/// One `git status --porcelain` captures the whole working set: staged and
/// unstaged modifications plus untracked files. Deterministic; a non-git
/// directory simply reports no changes rather than failing.
public enum GitDiff {

    /// Repo-relative paths that are staged, modified, or untracked in `root`.
    /// Empty when `root` is not a git repo or git is unavailable.
    public static func changedFiles(in root: URL, runner: ProcessRunner = ProcessRunner()) -> Set<String> {
        guard let result = try? runner.run(
            "git",
            arguments: ["-C", root.path, "status", "--porcelain"]
        ), result.exitCode == 0 else {
            return []
        }
        return Set(parsePorcelain(result.stdout))
    }

    /// Parses `git status --porcelain` (v1) output into repo-relative paths.
    /// Handles rename/copy entries (`orig -> new`, keeps `new`) and git's
    /// quoting of paths that contain special characters.
    static func parsePorcelain(_ output: String) -> [String] {
        var paths: [String] = []
        for rawLine in output.split(separator: "\n", omittingEmptySubsequences: true) {
            let line = String(rawLine)
            // Each entry is "XY path"; the two status columns plus a separator
            // occupy the first three characters, so the path starts at index 3.
            guard line.count > 3 else { continue }
            let start = line.index(line.startIndex, offsetBy: 3)
            var path = String(line[start...])

            // Rename/copy entries read "orig -> new"; the live file is `new`.
            if let arrow = path.range(of: " -> ") {
                path = String(path[arrow.upperBound...])
            }
            path = unquote(path)
            if !path.isEmpty { paths.append(path) }
        }
        return paths
    }

    /// Git wraps paths with unusual characters in double quotes. Strip a single
    /// surrounding pair; leave everything else untouched.
    private static func unquote(_ s: String) -> String {
        guard s.count >= 2, s.hasPrefix("\""), s.hasSuffix("\"") else { return s }
        return String(s.dropFirst().dropLast())
    }
}
