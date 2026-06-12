import XCTest
@testable import KujtoCore

final class BuildIssueParserTests: XCTestCase {
    func testParsesErrorWithColumn() {
        let line = "/Users/x/App/Login.swift:42:18: error: Cannot find 'user' in scope"
        let issue = BuildIssueParser().parse(line)
        XCTAssertEqual(issue?.severity, "error")
        XCTAssertEqual(issue?.file, "/Users/x/App/Login.swift")
        XCTAssertEqual(issue?.line, 42)
        XCTAssertEqual(issue?.column, 18)
        XCTAssertEqual(issue?.message, "Cannot find 'user' in scope")
    }

    func testParsesWarningWithoutColumn() {
        let line = "/repo/App/View.swift:10: warning: deprecated API used"
        let issue = BuildIssueParser().parse(line)
        XCTAssertEqual(issue?.severity, "warning")
        XCTAssertEqual(issue?.line, 10)
        XCTAssertNil(issue?.column)
    }

    func testIgnoresUnrelatedLines() {
        let parser = BuildIssueParser()
        XCTAssertNil(parser.parse("Build settings from command line:"))
        XCTAssertNil(parser.parse("** BUILD SUCCEEDED **"))
        XCTAssertNil(parser.parse(""))
    }
}
