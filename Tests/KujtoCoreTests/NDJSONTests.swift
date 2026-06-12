import XCTest
@testable import KujtoCore

final class NDJSONTests: XCTestCase {
    func testEncodesScalarsAndSortedKeys() {
        let encoder = NDJSONEncoder()
        let event = NDJSONEvent(type: "build_issue", [
            "severity": .string("error"),
            "file": .string("App/Login.swift"),
            "line": .int(42)
        ])
        let line = encoder.encode(event)
        XCTAssertEqual(
            line,
            #"{"file":"App/Login.swift","line":42,"severity":"error","type":"build_issue"}"#
        )
    }

    func testEscapesControlAndQuoteChars() {
        let encoder = NDJSONEncoder()
        let event = NDJSONEvent(type: "app_log", [
            "message": .string("say \"hi\"\nand bye")
        ])
        let line = encoder.encode(event)
        XCTAssertTrue(line.contains(#"\""#))
        XCTAssertTrue(line.contains(#"\n"#))
    }

    func testNestedArraysAndObjects() {
        let encoder = NDJSONEncoder()
        let event = NDJSONEvent(fields: [
            "type": .string("context"),
            "schemes": .array([.string("App"), .string("AppTests")]),
            "config": .object(["scheme": .string("App")])
        ])
        let line = encoder.encode(event)
        XCTAssertEqual(
            line,
            #"{"config":{"scheme":"App"},"schemes":["App","AppTests"],"type":"context"}"#
        )
    }
}
