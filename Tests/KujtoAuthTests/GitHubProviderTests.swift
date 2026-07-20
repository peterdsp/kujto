import XCTest
@testable import KujtoAuth

/// Parser tests pin the GitHub response shapes we depend on, including the
/// device-flow quirk that the token endpoint returns 200 with an error field.
final class GitHubProviderTests: XCTestCase {
    private let provider = GitHubProvider(clientID: "Iv1.test")

    func testParseDeviceCode() throws {
        let response = HTTPResponse.json(200, [
            "device_code": "dev123", "user_code": "WXYZ-1234",
            "verification_uri": "https://github.com/login/device",
            "expires_in": 900, "interval": 5
        ])
        let grant = try provider.parseDeviceCode(response)
        XCTAssertEqual(grant.userCode, "WXYZ-1234")
        XCTAssertEqual(grant.interval, 5)
        XCTAssertEqual(grant.expiresIn, 900)
    }

    func testParseTokenAuthorized() throws {
        let response = HTTPResponse.json(200, ["access_token": "gho_abc", "token_type": "bearer"])
        XCTAssertEqual(try provider.parseToken(response), .authorized("gho_abc"))
    }

    func testParseTokenPendingAndSlowDown() throws {
        XCTAssertEqual(try provider.parseToken(.json(200, ["error": "authorization_pending"])), .pending)
        XCTAssertEqual(try provider.parseToken(.json(200, ["error": "slow_down"])), .slowDown)
        XCTAssertEqual(try provider.parseToken(.json(200, ["error": "expired_token"])), .expired)
        XCTAssertEqual(try provider.parseToken(.json(200, ["error": "access_denied"])), .denied)
    }

    func testParseUserLogin() throws {
        XCTAssertEqual(try provider.parseUserLogin(.json(200, ["login": "ada"])), "ada")
    }

    func testParseRepoFound() throws {
        let repo = try provider.parseRepo(.json(200, Sample.repoJSON()))
        XCTAssertEqual(repo?.fullName, "ada/kujto-memory")
        XCTAssertEqual(repo?.sshURL, "git@github.com:ada/kujto-memory.git")
        XCTAssertTrue(repo?.isPrivate ?? false)
    }

    func testParseRepoNotFoundIsNil() throws {
        XCTAssertNil(try provider.parseRepo(HTTPResponse(status: 404)))
    }

    func testParseRepoUnexpectedStatusThrows() {
        XCTAssertThrowsError(try provider.parseRepo(HTTPResponse(status: 500)))
    }

    func testDeviceCodeRequestShape() {
        let request = provider.deviceCodeRequest(scopes: ["repo"])
        XCTAssertEqual(request.method, "POST")
        XCTAssertTrue(request.url.path.hasSuffix("/login/device/code"))
        let body = String(data: request.body ?? Data(), encoding: .utf8) ?? ""
        XCTAssertTrue(body.contains("client_id=Iv1.test"))
        XCTAssertTrue(body.contains("scope=repo"))
    }

    func testCreateRepoRequestIsPrivate() throws {
        let request = provider.createRepoRequest(name: "kujto-memory", isPrivate: true, token: "gho_abc")
        XCTAssertTrue(request.url.path.hasSuffix("/user/repos"))
        XCTAssertEqual(request.headers["Authorization"], "Bearer gho_abc")
        let json = try XCTUnwrap(try JSONSerialization.jsonObject(with: request.body ?? Data()) as? [String: Any])
        XCTAssertEqual(json["name"] as? String, "kujto-memory")
        XCTAssertEqual(json["private"] as? Bool, true)
    }
}
