import XCTest
@testable import KujtoAuth

/// The in-memory store defines the store contract the Keychain store mirrors.
final class TokenStoreTests: XCTestCase {
    func testSaveReadDelete() throws {
        let store = InMemoryTokenStore()
        try store.save("gho_1", provider: "github", account: "ada")
        XCTAssertEqual(store.read(provider: "github", account: "ada"), "gho_1")

        try store.delete(provider: "github", account: "ada")
        XCTAssertNil(store.read(provider: "github", account: "ada"))
    }

    func testAccountsAreIsolated() throws {
        let store = InMemoryTokenStore()
        try store.save("a", provider: "github", account: "ada")
        try store.save("b", provider: "github", account: "bo")
        XCTAssertEqual(store.read(provider: "github", account: "ada"), "a")
        XCTAssertEqual(store.read(provider: "github", account: "bo"), "b")
    }

    func testMissingIsNil() {
        XCTAssertNil(InMemoryTokenStore().read(provider: "github", account: "nobody"))
    }
}
