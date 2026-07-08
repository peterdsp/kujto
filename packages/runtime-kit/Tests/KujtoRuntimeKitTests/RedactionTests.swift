import XCTest
@testable import KujtoRuntimeKit

/// Redaction is the only thing users trust the kit to do right. If it
/// leaks a token from a nested dictionary once, the whole kit is a
/// liability. These tests pin the exact behaviour so future edits do not
/// widen the surface accidentally.
final class RedactionTests: XCTestCase {
    func testRedactsFlatTokenKey() {
        let out = KujtoRuntime.debugRedact(["userToken": "abc123", "name": "petros"])
        XCTAssertEqual(out["userToken"] as? String, "<redacted>")
        XCTAssertEqual(out["name"] as? String, "petros")
    }

    func testRedactsNestedSecret() {
        // The "user" top-level key doesn't match the deny-list, so recursion
        // continues into it. "password" inside does match, so only that key
        // gets scrubbed; peer keys pass through.
        let out = KujtoRuntime.debugRedact([
            "user": ["password": "hunter2", "id": "42"],
            "route": "/home"
        ])
        let user = out["user"] as? [String: Any] ?? [:]
        XCTAssertEqual(user["password"] as? String, "<redacted>")
        XCTAssertEqual(user["id"] as? String, "42")
    }

    func testWholeSubtreeRedactedWhenParentKeyMatches() {
        // When a parent key itself is on the deny list ("session"), the
        // entire subtree is scrubbed. Defence in depth - we never trust
        // a "session" dictionary's contents.
        let out = KujtoRuntime.debugRedact(["session": ["password": "hunter2", "id": "42"]])
        XCTAssertEqual(out["session"] as? String, "<redacted>")
    }

    func testCaseInsensitiveMatch() {
        let out = KujtoRuntime.debugRedact(["APIKey": "sk-abc", "APIkey": "sk-def"])
        XCTAssertEqual(out["APIKey"] as? String, "<redacted>")
        XCTAssertEqual(out["APIkey"] as? String, "<redacted>")
    }

    func testUnrelatedKeysPassThrough() {
        let out = KujtoRuntime.debugRedact(["route": "/home", "count": 3, "meta": ["stage": "prod"]])
        XCTAssertEqual(out["route"] as? String, "/home")
        XCTAssertEqual(out["count"] as? Int, 3)
        XCTAssertEqual((out["meta"] as? [String: Any])?["stage"] as? String, "prod")
    }

    func testArraysAreTraversed() {
        // Deliberately not using "sessions" as the outer key - that would
        // hit the deny list ("session") and scrub the whole subtree.
        let payload: [String: Any] = [
            "events": [
                ["userToken": "abc", "id": 1],
                ["userToken": "def", "id": 2]
            ]
        ]
        let out = KujtoRuntime.debugRedact(payload)
        let arr = out["events"] as? [Any] ?? []
        XCTAssertEqual(arr.count, 2)
        guard arr.count == 2,
              let first = arr[0] as? [String: Any] else {
            XCTFail("expected two dict elements"); return
        }
        XCTAssertEqual(first["userToken"] as? String, "<redacted>")
        XCTAssertEqual(first["id"] as? Int, 1)
    }
}
