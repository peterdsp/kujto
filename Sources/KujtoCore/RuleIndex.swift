import Foundation

/// File-scoped memory. The keystone of Kujto Studio's "Before You Touch This
/// File" screen: given a file path, return every memory or skill rule whose
/// `applies_to` globs match, ranked by specificity.
///
/// Today memory is global (read every session). A rule becomes file-scoped by
/// adding frontmatter:
///
///     ---
///     applies_to:
///       - "**/*Reducer.swift"
///       - "**/Checkout*/**"
///     risk: payment
///     ---
///
/// Files without `applies_to` are base memory (always read): they surface
/// through `alwaysOn`, not through `resolve(file:)`.

/// One memory or skill file, with its file-scoping frontmatter parsed out.
public struct Rule: Sendable, Equatable {
    public enum Kind: String, Sendable {
        case memory
        case skill
    }

    /// Path relative to the repo root, e.g. `memory/domains/ios/architectures/tca.md`.
    public let path: String
    /// First `# ...` heading, or the file name when there is none.
    public let title: String
    /// Glob patterns from `applies_to`. Empty means base memory (always on).
    public let appliesTo: [String]
    /// Optional `risk` tags, e.g. `payment`, `auth`, `onboarding`.
    public let risk: [String]
    public let kind: Kind

    public init(path: String, title: String, appliesTo: [String], risk: [String], kind: Kind) {
        self.path = path
        self.title = title
        self.appliesTo = appliesTo
        self.risk = risk
        self.kind = kind
    }
}

/// A rule that matched a file, with the winning glob and its specificity score.
public struct RuleMatch: Sendable, Equatable {
    public let rule: Rule
    /// The single most specific glob on the rule that matched the file.
    public let glob: String
    /// Higher = more specific. Used to rank matches.
    public let score: Int

    public init(rule: Rule, glob: String, score: Int) {
        self.rule = rule
        self.glob = glob
        self.score = score
    }
}

public final class RuleIndex {
    public let rules: [Rule]

    public init(rules: [Rule]) {
        self.rules = rules
    }

    /// Base memory: rules with no `applies_to`, read in every session.
    public var alwaysOn: [Rule] {
        rules.filter { $0.appliesTo.isEmpty }
    }

    /// Scans `memory/` and `skills/` under `root` for `.md` files and parses
    /// their frontmatter into rules.
    public static func load(root: URL) throws -> RuleIndex {
        let fm = FileManager.default
        var rules: [Rule] = []

        let scopes: [(String, Rule.Kind)] = [("memory", .memory), ("skills", .skill)]
        for (dir, kind) in scopes {
            let base = root.appendingPathComponent(dir)
            guard let enumerator = fm.enumerator(at: base, includingPropertiesForKeys: nil) else { continue }
            for case let url as URL in enumerator where url.pathExtension == "md" {
                guard let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
                let relative = url.path.hasPrefix(root.path + "/")
                    ? String(url.path.dropFirst(root.path.count + 1))
                    : url.path
                rules.append(Self.parse(text: text, path: relative, kind: kind))
            }
        }

        rules.sort { $0.path < $1.path }
        return RuleIndex(rules: rules)
    }

    /// Returns every rule whose globs match `relativePath`, most specific first.
    /// `relativePath` is repo-relative, e.g. `App/Sources/Home/HomeReducer.swift`.
    public func resolve(file relativePath: String) -> [RuleMatch] {
        let path = relativePath.hasPrefix("./") ? String(relativePath.dropFirst(2)) : relativePath
        var matches: [RuleMatch] = []

        for rule in rules where !rule.appliesTo.isEmpty {
            var best: (glob: String, score: Int)?
            for glob in rule.appliesTo where Glob.matches(glob, path: path) {
                let score = Glob.specificity(glob)
                if best == nil || score > best!.score {
                    best = (glob, score)
                }
            }
            if let best {
                matches.append(RuleMatch(rule: rule, glob: best.glob, score: best.score))
            }
        }

        matches.sort {
            $0.score != $1.score ? $0.score > $1.score : $0.rule.path < $1.rule.path
        }
        return matches
    }

    /// Content-scoped resolution for surfaces that have the file's text but not
    /// its path, such as an Xcode Source Editor extension. Each rule's globs
    /// yield signal tokens (`**/*Reducer.swift` -> `Reducer`); a rule matches
    /// when one of its tokens appears as a CamelCase identifier in `text`.
    /// In each `RuleMatch`, `glob` carries the signal token that matched.
    public func resolveByContent(_ text: String) -> [RuleMatch] {
        var matches: [RuleMatch] = []

        for rule in rules where !rule.appliesTo.isEmpty {
            var best: (signal: String, score: Int)?
            for glob in rule.appliesTo {
                for token in Glob.signalTokens(glob) where Self.containsSignal(token, in: text) {
                    let score = token.count
                    if best == nil || score > best!.score {
                        best = (token, score)
                    }
                }
            }
            if let best {
                matches.append(RuleMatch(rule: rule, glob: best.signal, score: best.score))
            }
        }

        matches.sort {
            $0.score != $1.score ? $0.score > $1.score : $0.rule.path < $1.rule.path
        }
        return matches
    }

    /// True when `token` appears in `text` as a CamelCase component: the same
    /// token followed by anything that is not a lowercase letter, so `Reducer`
    /// matches `HomeReducer` and `Reducer:` but not `Reducers`.
    static func containsSignal(_ token: String, in text: String) -> Bool {
        let pattern = NSRegularExpression.escapedPattern(for: token) + "(?![a-z])"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return false }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.firstMatch(in: text, range: range) != nil
    }

    // MARK: - Frontmatter

    /// Parses a single file's text into a `Rule`. Reads YAML frontmatter
    /// (between leading `---` fences) for `applies_to` and `risk`, and the
    /// first `# ...` heading for the title.
    static func parse(text: String, path: String, kind: Rule.Kind) -> Rule {
        let frontmatter = extractFrontmatter(text)
        let appliesTo = frontmatter["applies_to"] ?? []
        let risk = frontmatter["risk"] ?? []
        let title = firstHeading(text) ?? (path as NSString).lastPathComponent
        return Rule(path: path, title: title, appliesTo: appliesTo, risk: risk, kind: kind)
    }

    private static func firstHeading(_ text: String) -> String? {
        for raw in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("# ") {
                return String(line.dropFirst(2)).trimmingCharacters(in: .whitespaces)
            }
        }
        return nil
    }

    /// Minimal YAML-frontmatter reader. Supports `key: scalar`,
    /// `key: [a, b]`, and block lists (`key:` then `  - item` lines).
    /// Values are returned as string arrays; quotes are stripped.
    static func extractFrontmatter(_ text: String) -> [String: [String]] {
        let lines = text.components(separatedBy: "\n")
        guard lines.first?.trimmingCharacters(in: .whitespaces) == "---" else { return [:] }

        var result: [String: [String]] = [:]
        var currentKey: String?
        var i = 1
        while i < lines.count {
            let line = lines[i]
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed == "---" { break }
            i += 1
            if trimmed.isEmpty { continue }

            // Block-list item under the current key.
            if trimmed.hasPrefix("- "), let key = currentKey {
                result[key, default: []].append(unquote(String(trimmed.dropFirst(2))))
                continue
            }

            // `key: ...`
            guard let colon = trimmed.firstIndex(of: ":") else { continue }
            let key = String(trimmed[..<colon]).trimmingCharacters(in: .whitespaces)
            let rawValue = String(trimmed[trimmed.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
            currentKey = key

            if rawValue.isEmpty {
                result[key] = result[key] ?? []
            } else if rawValue.hasPrefix("[") && rawValue.hasSuffix("]") {
                let inner = rawValue.dropFirst().dropLast()
                let items = inner.split(separator: ",").map { unquote($0.trimmingCharacters(in: .whitespaces)) }
                result[key] = items.filter { !$0.isEmpty }
            } else {
                result[key] = [unquote(rawValue)]
            }
        }
        return result
    }

    private static func unquote(_ s: String) -> String {
        var v = s.trimmingCharacters(in: .whitespaces)
        if (v.hasPrefix("\"") && v.hasSuffix("\"")) || (v.hasPrefix("'") && v.hasSuffix("'")), v.count >= 2 {
            v = String(v.dropFirst().dropLast())
        }
        return v
    }
}

/// Tiny glob engine for `applies_to` patterns. Supports `**` (any path,
/// including across `/`), `*` (any run within one segment), and `?`.
public enum Glob {
    public static func matches(_ glob: String, path: String) -> Bool {
        guard let regex = try? NSRegularExpression(pattern: regexPattern(from: glob)) else {
            return false
        }
        let range = NSRange(path.startIndex..<path.endIndex, in: path)
        return regex.firstMatch(in: path, range: range) != nil
    }

    /// Higher = more specific. Literal characters count for more than
    /// wildcards, so `**/HomeReducer.swift` outranks `**/*.swift`.
    public static func specificity(_ glob: String) -> Int {
        let literals = glob.filter { $0 != "*" && $0 != "?" }.count
        let wildcards = glob.filter { $0 == "*" || $0 == "?" }.count
        return literals * 10 - wildcards
    }

    /// Signal tokens for content-scoped matching: the literal CamelCase words
    /// in a glob's file-name stem. `**/*Reducer.swift` -> `["Reducer"]`,
    /// `**/*SnapshotTests.swift` -> `["SnapshotTests", "Snapshot", "Tests"]`.
    /// Path-only globs like `**/__Snapshots__/**` yield nothing.
    public static func signalTokens(_ glob: String) -> [String] {
        let lastComponent = glob.split(separator: "/").last.map(String.init) ?? glob
        let stem = lastComponent.split(separator: ".").first.map(String.init) ?? lastComponent
        let cleaned = stem.filter { $0 != "*" && $0 != "?" && $0 != "_" }
        guard cleaned.count >= 4, cleaned.allSatisfy({ $0.isLetter }) else { return [] }

        var tokens: Set<String> = [cleaned]
        for word in camelWords(cleaned) where word.count >= 4 {
            tokens.insert(word)
        }
        return tokens.sorted { $0.count > $1.count }
    }

    private static func camelWords(_ s: String) -> [String] {
        var words: [String] = []
        var current = ""
        for c in s {
            if c.isUppercase, !current.isEmpty, let last = current.last, last.isLowercase {
                words.append(current)
                current = String(c)
            } else {
                current.append(c)
            }
        }
        if !current.isEmpty { words.append(current) }
        return words
    }

    static func regexPattern(from glob: String) -> String {
        let chars = Array(glob)
        var out = "^"
        var i = 0
        while i < chars.count {
            let c = chars[i]
            switch c {
            case "*":
                if i + 1 < chars.count && chars[i + 1] == "*" {
                    // `**/` matches zero or more leading directories;
                    // a bare `**` matches anything including `/`.
                    if i + 2 < chars.count && chars[i + 2] == "/" {
                        out += "(?:.*/)?"
                        i += 3
                    } else {
                        out += ".*"
                        i += 2
                    }
                    continue
                } else {
                    out += "[^/]*"
                }
            case "?":
                out += "[^/]"
            case ".", "(", ")", "+", "|", "^", "$", "{", "}", "[", "]", "\\":
                out += "\\" + String(c)
            default:
                out += String(c)
            }
            i += 1
        }
        out += "$"
        return out
    }
}
