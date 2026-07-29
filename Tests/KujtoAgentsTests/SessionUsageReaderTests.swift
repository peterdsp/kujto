import XCTest
@testable import KujtoAgents

final class SessionUsageReaderTests: XCTestCase {
    private let reader = SessionUsageReader()

    func testParsesValidLine() {
        let line = """
        {"sessionId":"abc","timestamp":"2026-01-15T10:30:00Z","message":{"model":"claude-sonnet-4","usage":{"input_tokens":1000,"output_tokens":500,"cache_read_input_tokens":200,"cache_creation_input_tokens":100}}}
        """
        let usage = reader.parseLine(line)
        XCTAssertNotNil(usage)
        XCTAssertEqual(usage?.sessionID, "abc")
        XCTAssertEqual(usage?.model, "claude-sonnet-4")
        XCTAssertEqual(usage?.inputTokens, 1000)
        XCTAssertEqual(usage?.outputTokens, 500)
        XCTAssertEqual(usage?.cacheReadTokens, 200)
        XCTAssertEqual(usage?.cacheWriteTokens, 100)
    }

    func testSkipsNonUsageLines() {
        XCTAssertNil(reader.parseLine("not json at all"))
        XCTAssertNil(reader.parseLine("{}"))
        XCTAssertNil(reader.parseLine("{\"message\":{}}"))
    }

    func testSkipsZeroTokenRecords() {
        let line = """
        {"sessionId":"x","message":{"model":"claude-sonnet-4","usage":{"input_tokens":0,"output_tokens":0}}}
        """
        XCTAssertNil(reader.parseLine(line))
    }

    func testToleratesStringTokenCounts() {
        let line = """
        {"sessionId":"x","message":{"model":"claude-sonnet-4","usage":{"input_tokens":"42","output_tokens":"10"}}}
        """
        let usage = reader.parseLine(line)
        XCTAssertEqual(usage?.inputTokens, 42)
        XCTAssertEqual(usage?.outputTokens, 10)
    }

    func testToleratesUnixEpochTimestamp() {
        let line = """
        {"sessionId":"x","timestamp":1700000000,"message":{"model":"m","usage":{"input_tokens":1,"output_tokens":1}}}
        """
        let usage = reader.parseLine(line)
        XCTAssertNotNil(usage)
        XCTAssertEqual(usage!.timestamp.timeIntervalSince1970, 1700000000, accuracy: 1)
    }

    func testToleratesFractionalISO8601() {
        let line = """
        {"sessionId":"x","timestamp":"2026-01-15T10:30:00.123Z","message":{"model":"m","usage":{"input_tokens":1,"output_tokens":1}}}
        """
        let usage = reader.parseLine(line)
        XCTAssertNotNil(usage)
    }

    func testReadsProject() {
        let line = """
        {"sessionId":"x","cwd":"/Users/me/project","message":{"model":"m","usage":{"input_tokens":1,"output_tokens":1}}}
        """
        XCTAssertEqual(reader.parseLine(line)?.project, "/Users/me/project")
    }

    func testModelFamilyName() {
        XCTAssertEqual(ModelSlice.familyName("claude-sonnet-4-20260115"), "claude-sonnet-4")
        XCTAssertEqual(ModelSlice.familyName("claude-opus-4"), "claude-opus-4")
        XCTAssertEqual(ModelSlice.familyName("gpt-4o"), "gpt-4o")
        XCTAssertEqual(ModelSlice.familyName("claude-fable-5-20260301"), "claude-fable-5")
    }
}
