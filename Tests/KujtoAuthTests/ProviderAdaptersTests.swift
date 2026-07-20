import XCTest
@testable import KujtoAuth

/// GitLab and Gitea adapters. The device-flow client and provisioner are
/// provider-agnostic, so these tests pin the two things that differ per host:
/// the response parsers, and (for GitLab) that provisioning works end to end
/// through the same coordinator.
final class ProviderAdaptersTests: XCTestCase {

    // MARK: GitLab

    private let gitlab = GitLabProvider(clientID: "gl_client")

    func testGitLabParsesUsernameAsLogin() throws {
        XCTAssertEqual(try gitlab.parseUserLogin(.json(200, ["username": "ada", "id": 7])), "ada")
    }

    func testGitLabParsesProjectShape() throws {
        let repo = try gitlab.parseRepo(.json(200, [
            "path_with_namespace": "ada/kujto-memory",
            "http_url_to_repo": "https://gitlab.com/ada/kujto-memory.git",
            "ssh_url_to_repo": "git@gitlab.com:ada/kujto-memory.git",
            "visibility": "private"
        ]))
        XCTAssertEqual(repo?.fullName, "ada/kujto-memory")
        XCTAssertEqual(repo?.sshURL, "git@gitlab.com:ada/kujto-memory.git")
        XCTAssertTrue(repo?.isPrivate ?? false)
    }

    func testGitLabPublicVisibilityIsNotPrivate() throws {
        let repo = try gitlab.parseRepo(.json(200, [
            "path_with_namespace": "ada/x", "http_url_to_repo": "https://gitlab.com/ada/x.git",
            "ssh_url_to_repo": "git@gitlab.com:ada/x.git", "visibility": "public"
        ]))
        XCTAssertEqual(repo?.isPrivate, false)
    }

    func testGitLabGetRepoRequestEncodesSlashOnce() {
        let request = gitlab.getRepoRequest(owner: "ada", name: "kujto-memory", token: "t")
        // The raw URL keeps the single %2F; url.path decodes it back to a slash.
        XCTAssertTrue(request.url.absoluteString.contains("projects/ada%2Fkujto-memory"))
        XCTAssertFalse(request.url.absoluteString.contains("%252F"), "must not double-encode")
    }

    func testGitLabDeviceCodeEndpoint() {
        let request = gitlab.deviceCodeRequest(scopes: ["api"])
        XCTAssertTrue(request.url.path.hasSuffix("/oauth/authorize_device"))
    }

    // MARK: Gitea

    private let gitea = GiteaProvider(clientID: "gt_client", base: URL(string: "https://git.example.dev")!)

    func testGiteaParsesLogin() throws {
        XCTAssertEqual(try gitea.parseUserLogin(.json(200, ["login": "bo"])), "bo")
    }

    func testGiteaParsesGitHubShapedRepo() throws {
        let repo = try gitea.parseRepo(.json(200, [
            "full_name": "bo/kujto-memory",
            "clone_url": "https://git.example.dev/bo/kujto-memory.git",
            "ssh_url": "git@git.example.dev:bo/kujto-memory.git",
            "private": true
        ]))
        XCTAssertEqual(repo?.fullName, "bo/kujto-memory")
        XCTAssertTrue(repo?.isPrivate ?? false)
    }

    func testGiteaUsesApiV1Paths() {
        let request = gitea.getRepoRequest(owner: "bo", name: "kujto-memory", token: "t")
        XCTAssertTrue(request.url.path.hasSuffix("/api/v1/repos/bo/kujto-memory"))
    }

    // MARK: End to end through the shared coordinator

    func testGitLabProvisioningThroughSharedCoordinator() async throws {
        let transport = MockTransport { request in
            let path = request.url.path
            if path.hasSuffix("/oauth/authorize_device") {
                return .json(200, [
                    "device_code": "d", "user_code": "GL-1",
                    "verification_uri": "https://gitlab.com/-/device", "expires_in": 100, "interval": 1
                ])
            }
            if path.hasSuffix("/oauth/token") { return .json(200, ["access_token": "glpat_live"]) }
            if path.hasSuffix("/api/v4/user") { return .json(200, ["username": "ada"]) }
            if path.hasSuffix("/projects/ada/kujto-memory") { return HTTPResponse(status: 404) }
            if path.hasSuffix("/api/v4/projects") {
                return .json(201, [
                    "path_with_namespace": "ada/kujto-memory",
                    "http_url_to_repo": "https://gitlab.com/ada/kujto-memory.git",
                    "ssh_url_to_repo": "git@gitlab.com:ada/kujto-memory.git",
                    "visibility": "private"
                ])
            }
            return .json(500, [:])
        }
        let tokens = InMemoryTokenStore()
        let coordinator = ProvisioningCoordinator(
            provider: gitlab, transport: transport, tokens: tokens, sleeper: RecordingSleeper(), scopes: ["api"])

        let result = try await coordinator.provision { _ in }
        XCTAssertEqual(result.login, "ada")
        XCTAssertEqual(result.repo.fullName, "ada/kujto-memory")
        XCTAssertTrue(result.created)
        XCTAssertEqual(tokens.read(provider: "gitlab", account: "ada"), "glpat_live")
    }
}
