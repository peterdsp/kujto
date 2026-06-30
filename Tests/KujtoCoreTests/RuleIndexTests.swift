import XCTest
@testable import KujtoCore

final class RuleIndexTests: XCTestCase {

    // MARK: - Glob

    func testGlobMatchesDoubleStarAcrossDirectories() {
        XCTAssertTrue(Glob.matches("**/*Reducer.swift", path: "App/Sources/Home/HomeReducer.swift"))
        XCTAssertTrue(Glob.matches("**/*Reducer.swift", path: "HomeReducer.swift"))
        XCTAssertFalse(Glob.matches("**/*Reducer.swift", path: "App/Sources/Home/HomeView.swift"))
    }

    func testGlobSingleStarStaysWithinSegment() {
        XCTAssertTrue(Glob.matches("Checkout*/**", path: "CheckoutFeature/Pay.swift"))
        XCTAssertFalse(Glob.matches("*.swift", path: "App/Home.swift"))
        XCTAssertTrue(Glob.matches("*.swift", path: "Home.swift"))
    }

    func testGlobQuestionMark() {
        XCTAssertTrue(Glob.matches("V?.swift", path: "V1.swift"))
        XCTAssertFalse(Glob.matches("V?.swift", path: "V12.swift"))
    }

    func testSpecificityFavoursLiterals() {
        let specific = Glob.specificity("**/HomeReducer.swift")
        let loose = Glob.specificity("**/*.swift")
        XCTAssertGreaterThan(specific, loose)
    }

    // MARK: - Frontmatter

    func testExtractFrontmatterBlockList() {
        let text = """
        ---
        applies_to:
          - "**/*Reducer.swift"
          - "**/*Feature.swift"
        risk: payment
        ---

        # Title
        """
        let fm = RuleIndex.extractFrontmatter(text)
        XCTAssertEqual(fm["applies_to"], ["**/*Reducer.swift", "**/*Feature.swift"])
        XCTAssertEqual(fm["risk"], ["payment"])
    }

    func testExtractFrontmatterInlineArray() {
        let text = """
        ---
        risk: [payment, auth]
        ---
        # Title
        """
        XCTAssertEqual(RuleIndex.extractFrontmatter(text)["risk"], ["payment", "auth"])
    }

    func testNoFrontmatterMeansBaseMemory() {
        let rule = RuleIndex.parse(text: "# Just a title\n\nbody", path: "memory/x.md", kind: .memory)
        XCTAssertTrue(rule.appliesTo.isEmpty)
        XCTAssertEqual(rule.title, "Just a title")
    }

    // MARK: - Resolve and ranking

    func testResolveRanksMostSpecificFirst() {
        let broad = Rule(path: "memory/broad.md", title: "Broad", appliesTo: ["**/*.swift"], risk: [], kind: .memory)
        let tca = Rule(path: "memory/tca.md", title: "TCA", appliesTo: ["**/*Reducer.swift"], risk: [], kind: .memory)
        let base = Rule(path: "memory/base.md", title: "Base", appliesTo: [], risk: [], kind: .memory)
        let index = RuleIndex(rules: [broad, tca, base])

        let matches = index.resolve(file: "App/HomeReducer.swift")
        XCTAssertEqual(matches.map { $0.rule.title }, ["TCA", "Broad"])
        XCTAssertEqual(index.alwaysOn.map { $0.title }, ["Base"])
    }

    func testResolveEmptyWhenNothingMatches() {
        let tca = Rule(path: "memory/tca.md", title: "TCA", appliesTo: ["**/*Reducer.swift"], risk: [], kind: .memory)
        let index = RuleIndex(rules: [tca])
        XCTAssertTrue(index.resolve(file: "README.md").isEmpty)
    }

    // MARK: - Content-scoped resolution (Xcode extension path)

    func testSignalTokensFromGlobStem() {
        XCTAssertEqual(Glob.signalTokens("**/*Reducer.swift"), ["Reducer"])
        XCTAssertEqual(Glob.signalTokens("**/*Coordinator.swift"), ["Coordinator"])
        // Whole stem ranks before its CamelCase pieces.
        XCTAssertEqual(Glob.signalTokens("**/*SnapshotTests.swift"), ["SnapshotTests", "Snapshot", "Tests"])
        // Path-only globs carry no usable file-name signal.
        XCTAssertTrue(Glob.signalTokens("**/__Snapshots__/**").isEmpty)
    }

    func testContainsSignalRespectsCamelCaseSuffix() {
        XCTAssertTrue(RuleIndex.containsSignal("Reducer", in: "struct HomeReducer: Reducer {"))
        XCTAssertTrue(RuleIndex.containsSignal("Reducer", in: "@Reducer\nstruct Home {}"))
        XCTAssertFalse(RuleIndex.containsSignal("Reducer", in: "let reducers = [a, b]"))
        XCTAssertFalse(RuleIndex.containsSignal("Reducer", in: "// nothing relevant here"))
    }

    func testResolveByContentMatchesBufferText() {
        let tca = Rule(path: "memory/tca.md", title: "TCA", appliesTo: ["**/*Reducer.swift", "**/*Feature.swift"], risk: [], kind: .memory)
        let nav = Rule(path: "memory/nav.md", title: "Navigation", appliesTo: ["**/*Coordinator.swift"], risk: [], kind: .memory)
        let index = RuleIndex(rules: [tca, nav])

        let buffer = "import ComposableArchitecture\n@Reducer\nstruct HomeReducer { }"
        let matches = index.resolveByContent(buffer)
        XCTAssertEqual(matches.map { $0.rule.title }, ["TCA"])
        XCTAssertEqual(matches.first?.glob, "Reducer")
    }
}
