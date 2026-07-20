import Foundation
import KujtoCore
import KujtoGit

/// The rules-in-commit fusion, as data. This is the hero of the design: when
/// files are staged, each is run through `RuleIndex` right there in the commit
/// flow, so the panel can show "you are about to commit to PaymentClient.swift
/// (danger zone: payment, run these tests)" before the commit lands.
///
/// It is pure composition over engines that already exist (`RuleIndex`,
/// `RelatedTests`), so there is no new matching logic to test, only the
/// aggregation. The verdict is advisory and never blocks a commit.

/// One staged file's rule picture.
public struct FileInspection: Sendable, Equatable {
    public let path: String
    /// Rules that apply, ranked most specific first.
    public let rules: [RuleMatch]
    /// Union of risk tags across the matching rules, sorted.
    public let risk: [String]
    /// Related tests to run for this file.
    public let tests: [String]
    /// The per-file verdict.
    public let confidence: Confidence

    public init(path: String, rules: [RuleMatch], risk: [String], tests: [String], confidence: Confidence) {
        self.path = path
        self.rules = rules
        self.risk = risk
        self.tests = tests
        self.confidence = confidence
    }
}

/// The whole commit's rule picture: per-file detail plus the aggregate strip
/// the commit box shows.
public struct CommitInspection: Sendable, Equatable {
    public let files: [FileInspection]
    /// The worst per-file verdict, the one the banner reflects.
    public let verdict: Confidence
    /// Union of risk tags across every file, sorted.
    public let riskTags: [String]
    /// Union of related tests across every file, sorted.
    public let testsToRun: [String]

    public init(files: [FileInspection], verdict: Confidence, riskTags: [String], testsToRun: [String]) {
        self.files = files
        self.verdict = verdict
        self.riskTags = riskTags
        self.testsToRun = testsToRun
    }

    /// Nothing staged, or nothing matched: there is no strip to show.
    public var isEmpty: Bool { files.isEmpty }
    /// True when any file carries a risk tag, so the banner earns its danger color.
    public var hasRisk: Bool { !riskTags.isEmpty }
}

/// Composes `RuleIndex` and related-tests resolution over a commit's staged
/// paths. The tests resolver is injectable so the inspector is testable without
/// walking a real repo; the default binds it to `RelatedTests` under a root.
public struct CommitInspector {
    private let index: RuleIndex
    private let testsFor: (String) -> [String]

    /// Production: related tests are discovered under `root`.
    public init(index: RuleIndex, root: URL) {
        self.index = index
        self.testsFor = { path in RelatedTests.testsFor(file: path, in: root) }
    }

    /// Testable: supply the tests resolver directly.
    public init(index: RuleIndex, testsResolver: @escaping (String) -> [String]) {
        self.index = index
        self.testsFor = testsResolver
    }

    /// Inspect a set of repo-relative staged paths.
    public func inspect(paths: [String]) -> CommitInspection {
        let files = paths.map { path -> FileInspection in
            let matches = index.resolve(file: path)
            let risk = Array(Set(matches.flatMap { $0.rule.risk })).sorted()
            let confidence = index.confidence(forFile: path)
            return FileInspection(path: path, rules: matches, risk: risk,
                                  tests: testsFor(path), confidence: confidence)
        }
        let verdict = files.map(\.confidence).max(by: { Self.rank($0) < Self.rank($1) }) ?? .safe
        let riskTags = Array(Set(files.flatMap(\.risk))).sorted()
        let tests = Array(Set(files.flatMap(\.tests))).sorted()
        return CommitInspection(files: files, verdict: verdict, riskTags: riskTags, testsToRun: tests)
    }

    /// Convenience over staged `GitChange`s.
    public func inspect(staged: [GitChange]) -> CommitInspection {
        inspect(paths: staged.map(\.path))
    }

    /// Severity ordering so the aggregate verdict is the worst of the files.
    static func rank(_ confidence: Confidence) -> Int {
        switch confidence {
        case .safe: return 0
        case .needsContext: return 1
        case .dangerZone: return 2
        }
    }
}
