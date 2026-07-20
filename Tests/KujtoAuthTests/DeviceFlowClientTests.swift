import XCTest
@testable import KujtoAuth

/// The device-flow state machine: it must poll until approval, back off on
/// slow_down, and surface denial and expiry as errors, all without real waiting.
final class DeviceFlowClientTests: XCTestCase {
    private let provider = GitHubProvider(clientID: "Iv1.test")

    private func deviceCode(interval: Int = 1, expiresIn: Int = 100) -> HTTPResponse {
        .json(200, [
            "device_code": "dev123", "user_code": "WXYZ-1234",
            "verification_uri": "https://github.com/login/device",
            "expires_in": expiresIn, "interval": interval
        ])
    }

    func testAuthorizeReturnsTokenAfterPending() async throws {
        let polls = Counter()
        let transport = MockTransport { request in
            if request.url.path.hasSuffix("/login/device/code") { return self.deviceCode() }
            // First poll pending, then authorized.
            return polls.next() == 0
                ? .json(200, ["error": "authorization_pending"])
                : .json(200, ["access_token": "gho_final"])
        }
        let sleeper = RecordingSleeper()
        let client = DeviceFlowClient(provider: provider, transport: transport, sleeper: sleeper)

        var prompted: DeviceCodeGrant?
        let token = try await client.authorize(scopes: ["repo"]) { prompted = $0 }

        XCTAssertEqual(token, "gho_final")
        XCTAssertEqual(prompted?.userCode, "WXYZ-1234")
        XCTAssertEqual(sleeper.slept, [1, 1], "two polls at the base interval")
    }

    func testAuthorizeWidensIntervalOnSlowDown() async throws {
        let polls = Counter()
        let transport = MockTransport { request in
            if request.url.path.hasSuffix("/login/device/code") { return self.deviceCode(interval: 1) }
            return polls.next() == 0
                ? .json(200, ["error": "slow_down"])
                : .json(200, ["access_token": "gho_ok"])
        }
        let sleeper = RecordingSleeper()
        let client = DeviceFlowClient(provider: provider, transport: transport, sleeper: sleeper)

        let token = try await client.authorize(scopes: ["repo"]) { _ in }
        XCTAssertEqual(token, "gho_ok")
        // Base 1, then +5 after slow_down.
        XCTAssertEqual(sleeper.slept, [1, 6])
    }

    func testAuthorizeThrowsOnDenied() async {
        let transport = MockTransport { request in
            if request.url.path.hasSuffix("/login/device/code") { return self.deviceCode() }
            return .json(200, ["error": "access_denied"])
        }
        let client = DeviceFlowClient(provider: provider, transport: transport, sleeper: RecordingSleeper())
        do {
            _ = try await client.authorize(scopes: ["repo"]) { _ in }
            XCTFail("expected denial")
        } catch {
            XCTAssertEqual(error as? AuthError, .denied)
        }
    }

    func testAuthorizeExpiresWhenLifetimeExhausted() async {
        // interval 5, lifetime 3: one poll, then the loop guard trips.
        let transport = MockTransport { request in
            if request.url.path.hasSuffix("/login/device/code") { return self.deviceCode(interval: 5, expiresIn: 3) }
            return .json(200, ["error": "authorization_pending"])
        }
        let client = DeviceFlowClient(provider: provider, transport: transport, sleeper: RecordingSleeper())
        do {
            _ = try await client.authorize(scopes: ["repo"]) { _ in }
            XCTFail("expected expiry")
        } catch {
            XCTAssertEqual(error as? AuthError, .expired)
        }
    }
}
