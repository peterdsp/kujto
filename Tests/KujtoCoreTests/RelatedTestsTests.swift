import XCTest
@testable import KujtoCore

final class RelatedTestsTests: XCTestCase {

    // MARK: - Candidate names

    func testCandidatesIncludeStemPlusTests() {
        let c = RelatedTests.candidateNames(for: "HomeReducer")
        XCTAssertTrue(c.contains("HomeReducerTests"))
        XCTAssertTrue(c.contains("HomeReducerSpec"))
    }

    func testCandidatesStripKnownSuffixes() {
        let c = RelatedTests.candidateNames(for: "PaymentClient")
        XCTAssertTrue(c.contains("PaymentTests"))
        XCTAssertTrue(c.contains("PaymentClientTests"))
    }

    func testNoStripWhenStemMatchesSuffixExactly() {
        // "Reducer.swift" should not collapse to "Tests" (empty base).
        let c = RelatedTests.candidateNames(for: "Reducer")
        XCTAssertFalse(c.contains("Tests"))
        XCTAssertTrue(c.contains("ReducerTests"))
    }

    // MARK: - Repo walk

    private func makeRepo() throws -> URL {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("kujto-tests-\(UUID().uuidString)")
        let fm = FileManager.default
        try fm.createDirectory(at: root.appendingPathComponent("Sources/Home"), withIntermediateDirectories: true)
        try fm.createDirectory(at: root.appendingPathComponent("Tests"), withIntermediateDirectories: true)
        try fm.createDirectory(at: root.appendingPathComponent(".build/whatever"), withIntermediateDirectories: true)

        try "struct HomeReducer {}".write(
            to: root.appendingPathComponent("Sources/Home/HomeReducer.swift"),
            atomically: true, encoding: .utf8)
        try "final class HomeReducerTests: XCTestCase {}".write(
            to: root.appendingPathComponent("Tests/HomeReducerTests.swift"),
            atomically: true, encoding: .utf8)
        try "final class HomeTests: XCTestCase {}".write(
            to: root.appendingPathComponent("Tests/HomeTests.swift"),
            atomically: true, encoding: .utf8)
        try "// ignored under .build".write(
            to: root.appendingPathComponent(".build/whatever/HomeReducerTests.swift"),
            atomically: true, encoding: .utf8)
        return root
    }

    func testFindsDirectAndBaseNamedTests() throws {
        let root = try makeRepo()
        defer { try? FileManager.default.removeItem(at: root) }

        let hits = RelatedTests.testsFor(file: "Sources/Home/HomeReducer.swift", in: root)
        XCTAssertEqual(hits, ["Tests/HomeReducerTests.swift", "Tests/HomeTests.swift"])
    }

    func testExcludesBuildArtifacts() throws {
        let root = try makeRepo()
        defer { try? FileManager.default.removeItem(at: root) }

        let hits = RelatedTests.testsFor(file: "Sources/Home/HomeReducer.swift", in: root)
        XCTAssertFalse(hits.contains { $0.contains(".build") })
    }

    func testReturnsEmptyWhenNoMatch() throws {
        let root = try makeRepo()
        defer { try? FileManager.default.removeItem(at: root) }

        let hits = RelatedTests.testsFor(file: "Sources/Home/CheckoutFeature.swift", in: root)
        XCTAssertTrue(hits.isEmpty)
    }
}
