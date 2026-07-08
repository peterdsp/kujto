import Foundation

/// A structural disagreement between two Kujto rules. Deterministic detection
/// only - we never ask a model whether two English paragraphs contradict.
///
/// The heuristics err on the side of surfacing likely conflicts and letting
/// the user judge: overlapping globs with divergent risk tags, duplicated
/// rule titles across memory sources, and identical titles that live in
/// different chapters (a common sign of copy-paste drift).
public struct Conflict: Sendable, Equatable {
    public enum Kind: Sendable, Equatable {
        /// Two rules share the same title but sit at different paths. Almost
        /// always a copy-paste drift bug where an author forgot the original.
        case duplicateTitle
        /// Two rules' applies_to globs overlap on at least one common file
        /// pattern AND one carries a `risk` tag the other does not. This
        /// tends to catch "add a scoped rule but forget to update the base
        /// rule's risk" moments.
        case overlappingScope
    }

    public let kind: Kind
    public let first: Rule
    public let second: Rule
    /// One-sentence description surfaced by the UI.
    public let summary: String

    public init(kind: Kind, first: Rule, second: Rule, summary: String) {
        self.kind = kind
        self.first = first
        self.second = second
        self.summary = summary
    }
}

/// Detects structural conflicts across a `RuleIndex`. Runs O(n²) over rule
/// pairs; fine for the sizes Kujto memory reaches (hundreds, not millions).
public enum ConflictLens {
    public static func detect(in index: RuleIndex) -> [Conflict] {
        let rules = index.rules
        var out: [Conflict] = []

        for i in 0..<rules.count {
            for j in (i + 1)..<rules.count {
                let a = rules[i]
                let b = rules[j]

                // 1. Duplicate titles at different paths.
                if a.title.lowercased() == b.title.lowercased(),
                   a.path != b.path,
                   !a.title.isEmpty {
                    out.append(Conflict(
                        kind: .duplicateTitle,
                        first: a,
                        second: b,
                        summary: "Two rules share the title \"\(a.title)\". One of them is probably stale."
                    ))
                    continue
                }

                // 2. Overlapping scope with divergent risk.
                if !a.appliesTo.isEmpty, !b.appliesTo.isEmpty,
                   Self.overlaps(a.appliesTo, b.appliesTo),
                   Self.diverges(risk: a.risk, otherRisk: b.risk) {
                    let riskA = a.risk.isEmpty ? "no risk tag" : a.risk.joined(separator: ", ")
                    let riskB = b.risk.isEmpty ? "no risk tag" : b.risk.joined(separator: ", ")
                    out.append(Conflict(
                        kind: .overlappingScope,
                        first: a,
                        second: b,
                        summary: "Both rules cover the same files, but one is tagged \(riskA) and the other \(riskB)."
                    ))
                }
            }
        }
        return out
    }

    /// True when at least one glob in `a` equals a glob in `b`. Simple string
    /// equality is intentional - a full glob-intersection algorithm would
    /// spend a lot of code on very few false negatives.
    private static func overlaps(_ a: [String], _ b: [String]) -> Bool {
        let set = Set(a)
        return b.contains(where: set.contains)
    }

    /// Two risk sets diverge when their symmetric difference is non-empty:
    /// something exists in one that does not exist in the other.
    private static func diverges(risk a: [String], otherRisk b: [String]) -> Bool {
        Set(a).symmetricDifference(Set(b)).isEmpty == false
    }
}
