import XCTest
@testable import KujtoAuth

/// The factory is the single place providers are built from config, so it must
/// map each kind correctly and refuse incomplete configuration clearly.
final class ProviderFactoryTests: XCTestCase {

    func testMakesGitHub() throws {
        let provider = try ProviderFactory.make(ProviderConfig(kind: .github, clientID: "Iv1.x"))
        XCTAssertEqual(provider.name, "github")
    }

    func testMakesGitLab() throws {
        let provider = try ProviderFactory.make(ProviderConfig(kind: .gitlab, clientID: "gl"))
        XCTAssertEqual(provider.name, "gitlab")
    }

    func testMakesGiteaWithBase() throws {
        let provider = try ProviderFactory.make(
            ProviderConfig(kind: .gitea, clientID: "gt", baseURL: URL(string: "https://git.example.dev")!))
        XCTAssertEqual(provider.name, "gitea")
    }

    func testEmptyClientIDThrows() {
        XCTAssertThrowsError(try ProviderFactory.make(ProviderConfig(kind: .github, clientID: ""))) { error in
            XCTAssertEqual(error as? AuthError, .provider("missing client id for github"))
        }
    }

    func testGiteaWithoutBaseThrows() {
        XCTAssertThrowsError(try ProviderFactory.make(ProviderConfig(kind: .gitea, clientID: "gt"))) { error in
            XCTAssertEqual(error as? AuthError, .provider("gitea requires a base URL"))
        }
    }

    func testProviderNameNamespacesTokenAccount() {
        XCTAssertEqual(ProviderConfig(kind: .gitlab, clientID: "x").providerName, "gitlab")
    }
}
