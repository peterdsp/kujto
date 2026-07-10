import XCTest
@testable import KujtoCore

final class RuleProposalEngineTests: XCTestCase {

    /// Repo with `count` files ending in `suffix`, no memory rules unless
    /// `ruleGlob` is provided.
    private func makeRepo(suffix: String, count: Int, ruleGlob: String? = nil) throws -> URL {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("kujto-propose-\(UUID().uuidString)")
        let fm = FileManager.default
        try fm.createDirectory(at: root.appendingPathComponent("Sources"), withIntermediateDirectories: true)
        for i in 0..<count {
            try "struct A\(i)\(suffix) {}".write(
                to: root.appendingPathComponent("Sources/A\(i)\(suffix).swift"),
                atomically: true, encoding: .utf8)
        }
        if let ruleGlob {
            try fm.createDirectory(at: root.appendingPathComponent("memory"), withIntermediateDirectories: true)
            try """
            ---
            applies_to:
              - "\(ruleGlob)"
            ---
            # Existing rule
            """.write(to: root.appendingPathComponent("memory/existing.md"),
                      atomically: true, encoding: .utf8)
        }
        return root
    }

    func testProposesForUncoveredGroup() throws {
        let root = try makeRepo(suffix: "Reducer", count: 4)
        defer { try? FileManager.default.removeItem(at: root) }

        let proposals = try RuleProposalEngine.propose(in: root)
        XCTAssertEqual(proposals.count, 1)
        XCTAssertEqual(proposals[0].appliesTo, ["**/*Reducer.swift"])
        XCTAssertEqual(proposals[0].affectedFiles.count, 4)
    }

    func testNoProposalBelowThreshold() throws {
        let root = try makeRepo(suffix: "Reducer", count: 2)
        defer { try? FileManager.default.removeItem(at: root) }
        XCTAssertTrue(try RuleProposalEngine.propose(in: root, minFiles: 3).isEmpty)
    }

    func testCoveredGroupIsNotProposed() throws {
        let root = try makeRepo(suffix: "Reducer", count: 4, ruleGlob: "**/*Reducer.swift")
        defer { try? FileManager.default.removeItem(at: root) }
        XCTAssertTrue(try RuleProposalEngine.propose(in: root).isEmpty)
    }

    func testDraftHasFrontmatterAndReviewNote() throws {
        let root = try makeRepo(suffix: "Client", count: 3)
        defer { try? FileManager.default.removeItem(at: root) }

        let proposals = try RuleProposalEngine.propose(in: root)
        let draft = try XCTUnwrap(proposals.first).draftMarkdown
        XCTAssertTrue(draft.hasPrefix("---"))
        XCTAssertTrue(draft.contains("applies_to:"))
        XCTAssertTrue(draft.contains("**/*Client.swift"))
        XCTAssertTrue(draft.contains("Kujto never"))
    }

    func testDraftIsParseableBackIntoARule() throws {
        // The proposed draft must round-trip through the same frontmatter
        // reader the rest of Kujto uses, so adopting it just works.
        let root = try makeRepo(suffix: "Service", count: 3)
        defer { try? FileManager.default.removeItem(at: root) }

        let draft = try XCTUnwrap(try RuleProposalEngine.propose(in: root).first).draftMarkdown
        let rule = RuleIndex.parse(text: draft, path: "memory/proposed/service.md", kind: .memory)
        XCTAssertEqual(rule.appliesTo, ["**/*Service.swift"])
    }
}
