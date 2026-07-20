import XCTest
@testable import KujtoAuth

/// The provisioner and the end-to-end coordinator: find-or-create the private
/// memory repo, and prove the token is stored only after it is known good.
final class ProvisioningTests: XCTestCase {
    private let provider = GitHubProvider(clientID: "Iv1.test")

    // MARK: Provisioner

    func testCurrentUser() async throws {
        let transport = MockTransport { _ in .json(200, ["login": "ada"]) }
        let provisioner = MemoryRepoProvisioner(provider: provider, transport: transport)
        let login = try await provisioner.currentUser(token: "gho_x")
        XCTAssertEqual(login, "ada")
    }

    func testEnsureRepoFindsExisting() async throws {
        let transport = MockTransport { request in
            if request.url.path.hasSuffix("/repos/ada/kujto-memory") { return .json(200, Sample.repoJSON()) }
            return .json(500, [:])
        }
        let provisioner = MemoryRepoProvisioner(provider: provider, transport: transport)
        let (repo, created) = try await provisioner.ensureRepo(owner: "ada", name: "kujto-memory", token: "gho_x")
        XCTAssertEqual(repo.fullName, "ada/kujto-memory")
        XCTAssertFalse(created)
        // It must not attempt to create when the repo already exists.
        XCTAssertEqual(transport.requestCount(pathSuffix: "/user/repos", method: "POST"), 0)
    }

    func testEnsureRepoCreatesWhenAbsent() async throws {
        let transport = MockTransport { request in
            if request.url.path.hasSuffix("/repos/ada/kujto-memory") { return HTTPResponse(status: 404) }
            if request.url.path.hasSuffix("/user/repos") { return .json(201, Sample.repoJSON()) }
            return .json(500, [:])
        }
        let provisioner = MemoryRepoProvisioner(provider: provider, transport: transport)
        let (repo, created) = try await provisioner.ensureRepo(owner: "ada", name: "kujto-memory", token: "gho_x")
        XCTAssertEqual(repo.fullName, "ada/kujto-memory")
        XCTAssertTrue(created)
        XCTAssertEqual(transport.requestCount(pathSuffix: "/user/repos", method: "POST"), 1)
    }

    // MARK: Coordinator (end to end)

    private func coordinatorTransport(repoStatus: Int, existing: Bool) -> MockTransport {
        MockTransport { request in
            let path = request.url.path
            if path.hasSuffix("/login/device/code") {
                return .json(200, [
                    "device_code": "dev", "user_code": "CODE-1", "verification_uri": "https://github.com/login/device",
                    "expires_in": 100, "interval": 1
                ])
            }
            if path.hasSuffix("/login/oauth/access_token") { return .json(200, ["access_token": "gho_live"]) }
            if path.hasSuffix("/user") { return .json(200, ["login": "ada"]) }
            if path.hasSuffix("/repos/ada/kujto-memory") {
                return existing ? .json(200, Sample.repoJSON()) : HTTPResponse(status: 404)
            }
            if path.hasSuffix("/user/repos") { return .json(201, Sample.repoJSON()) }
            return .json(500, [:])
        }
    }

    func testProvisionFirstMachineCreatesAndStoresToken() async throws {
        let transport = coordinatorTransport(repoStatus: 404, existing: false)
        let tokens = InMemoryTokenStore()
        let coordinator = ProvisioningCoordinator(
            provider: provider, transport: transport, tokens: tokens, sleeper: RecordingSleeper())

        var prompted: DeviceCodeGrant?
        let result = try await coordinator.provision { prompted = $0 }

        XCTAssertEqual(prompted?.userCode, "CODE-1")
        XCTAssertEqual(result.login, "ada")
        XCTAssertEqual(result.repo.fullName, "ada/kujto-memory")
        XCTAssertTrue(result.created)
        // Token persisted under the resolved login, never before the user call.
        XCTAssertEqual(tokens.read(provider: "github", account: "ada"), "gho_live")
    }

    func testProvisionLaterMachineFindsExisting() async throws {
        let transport = coordinatorTransport(repoStatus: 200, existing: true)
        let coordinator = ProvisioningCoordinator(
            provider: provider, transport: transport, tokens: InMemoryTokenStore(), sleeper: RecordingSleeper())

        let result = try await coordinator.provision { _ in }
        XCTAssertFalse(result.created)
        XCTAssertEqual(transport.requestCount(pathSuffix: "/user/repos", method: "POST"), 0)
    }
}
