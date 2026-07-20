import Foundation
import KujtoGit

/// A credential the scanner found in a staged diff. The sync loop refuses to
/// commit when any hit is present, so a `.env`-shaped rule never leaves the
/// machine. Carries enough to point the user at the line, and a masked snippet
/// so the secret itself is never echoed into logs or the UI.
public struct SecretHit: Equatable, Sendable {
    public let file: String
    /// 1-based line number on the new side of the diff, best effort.
    public let line: Int
    /// Stable kind slug, for example `github-token`.
    public let kind: String
    /// The matched token with its middle masked. Never the raw secret.
    public let masked: String

    public init(file: String, line: Int, kind: String, masked: String) {
        self.file = file
        self.line = line
        self.kind = kind
        self.masked = masked
    }
}

/// Scans added diff lines for high-signal credential shapes. This is the same
/// discipline as Kujto's CI guards, moved into the sync loop so it runs before
/// every auto-commit. It targets tokens with distinctive prefixes to keep the
/// false-positive rate near zero; it is a safety net, not a secrets manager.
public struct SecretScanner: Sendable {
    private let patterns: [(kind: String, regex: NSRegularExpression)]

    public init() {
        let raw: [(String, String)] = [
            ("github-token", #"\bgh[posur]_[A-Za-z0-9]{36,255}\b"#),
            ("openai-anthropic-key", #"\bsk-(ant-)?[A-Za-z0-9_-]{20,}\b"#),
            ("aws-access-key", #"\bAKIA[0-9A-Z]{16}\b"#),
            ("google-api-key", #"\bAIza[0-9A-Za-z_-]{35}\b"#),
            ("slack-token", #"\bxox[baprs]-[A-Za-z0-9-]{10,}\b"#),
            ("private-key-block", #"-----BEGIN [A-Z ]*PRIVATE KEY-----"#)
        ]
        patterns = raw.compactMap { kind, pattern in
            guard let re = try? NSRegularExpression(pattern: pattern) else { return nil }
            return (kind, re)
        }
    }

    /// Scans every file diff and returns all hits across them.
    public func scanDiff(_ diffs: [GitFileDiff]) -> [SecretHit] {
        diffs.flatMap { scanPatch($0.patch, file: $0.path) }
    }

    /// Scans one unified-diff patch, tracking the new-side line number through
    /// hunk headers so a hit points at the right line.
    public func scanPatch(_ patch: String, file: String) -> [SecretHit] {
        var hits: [SecretHit] = []
        var newLine = 0

        for rawLine in patch.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = String(rawLine)

            if line.hasPrefix("@@") {
                if let start = Self.hunkNewStart(line) { newLine = start }
                continue
            }
            // Skip the file header lines; they are not content.
            if line.hasPrefix("+++") || line.hasPrefix("---") { continue }

            guard let first = line.first else { newLine += 1; continue }
            switch first {
            case "+":
                let content = String(line.dropFirst())
                for (kind, regex) in patterns {
                    if let match = Self.firstMatch(regex, in: content) {
                        hits.append(SecretHit(file: file, line: newLine, kind: kind, masked: Self.mask(match)))
                    }
                }
                newLine += 1
            case "-":
                // Removed line: no advance on the new side.
                break
            default:
                // Context or blank line advances the new side.
                newLine += 1
            }
        }
        return hits
    }

    /// True when any file diff contains a credential.
    public func hasSecret(in diffs: [GitFileDiff]) -> Bool {
        !scanDiff(diffs).isEmpty
    }

    // MARK: Helpers

    /// Extracts the `+c` start line from a `@@ -a,b +c,d @@` hunk header.
    static func hunkNewStart(_ header: String) -> Int? {
        guard let plus = header.range(of: "+") else { return nil }
        let rest = header[plus.upperBound...]
        let digits = rest.prefix { $0.isNumber }
        return Int(digits)
    }

    private static func firstMatch(_ regex: NSRegularExpression, in text: String) -> String? {
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: range),
              let matched = Range(match.range, in: text) else { return nil }
        return String(text[matched])
    }

    /// Masks the middle of a token so logs and UI never carry the raw value.
    static func mask(_ token: String) -> String {
        guard token.count > 8 else { return String(repeating: "*", count: token.count) }
        let head = token.prefix(4)
        let tail = token.suffix(2)
        return "\(head)***\(tail)"
    }
}
