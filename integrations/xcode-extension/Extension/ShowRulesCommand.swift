import Foundation
import XcodeKit
import KujtoCore

/// "Show Rules for This File" inside Xcode.
///
/// A Source Editor extension cannot see the file path or URL: the invocation
/// only carries the buffer text. So instead of path globs we use content
/// signals (`RuleIndex.resolveByContent`), then insert the matching rules as
/// an undoable comment block at the top of the buffer.
final class ShowRulesCommand: NSObject, XCSourceEditorCommand {
    func perform(with invocation: XCSourceEditorCommandInvocation,
                 completionHandler: @escaping (Error?) -> Void) {
        let buffer = invocation.buffer

        guard let root = SharedConfig.resolveRoot() else {
            insert(
                ["// Kujto: open the Kujto container app and pick your repo first."],
                into: buffer
            )
            completionHandler(nil)
            return
        }
        defer { root.stopAccessingSecurityScopedResource() }

        do {
            let index = try RuleIndex.load(root: root)
            let matches = index.resolveByContent(buffer.completeBuffer)
            insert(Self.render(matches), into: buffer)
            completionHandler(nil)
        } catch {
            insert(["// Kujto: could not load rules (\(error.localizedDescription))."], into: buffer)
            completionHandler(nil)
        }
    }

    /// Renders the comment block. Public-ish via `static` so it can be unit
    /// tested without an Xcode host.
    static func render(_ matches: [RuleMatch]) -> [String] {
        guard !matches.isEmpty else {
            return ["// Kujto: no file-scoped rules match this buffer. Base memory still applies."]
        }
        var out = ["// Kujto: before you touch this file"]
        for match in matches {
            let risk = match.rule.risk.isEmpty ? "" : "  [risk: \(match.rule.risk.joined(separator: ", "))]"
            out.append("//   \u{2022} \(match.rule.title)\(risk)")
            out.append("//       \(match.rule.path)  (signal: \(match.glob))")
        }
        return out
    }

    private func insert(_ lines: [String], into buffer: XCSourceTextBuffer) {
        let indices = IndexSet(integersIn: 0..<lines.count)
        buffer.lines.insert(lines, at: indices)
    }
}
