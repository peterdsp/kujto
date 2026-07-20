import Foundation

/// Drives OAuth device flow: request a code, let the caller show it, then poll
/// until the user approves in the browser. The sleeper is injected so the
/// polling backoff is deterministic under test. Elapsed time is tracked from
/// the sleeps we perform, not the wall clock, so the expiry guard is testable
/// without real waiting.
public struct DeviceFlowClient: Sendable {
    private let provider: GitProvider
    private let transport: HTTPTransport
    private let sleeper: AuthSleeper

    public init(provider: GitProvider, transport: HTTPTransport, sleeper: AuthSleeper = RealSleeper()) {
        self.provider = provider
        self.transport = transport
        self.sleeper = sleeper
    }

    /// Requests a fresh device code the caller can display.
    public func requestDeviceCode(scopes: [String]) async throws -> DeviceCodeGrant {
        let response = try await transport.send(provider.deviceCodeRequest(scopes: scopes))
        return try provider.parseDeviceCode(response)
    }

    /// Performs a single token poll.
    public func poll(_ grant: DeviceCodeGrant) async throws -> TokenPollResult {
        let response = try await transport.send(provider.tokenRequest(deviceCode: grant.deviceCode))
        return try provider.parseToken(response)
    }

    /// The full flow: request a code, hand it to `onPrompt` (the UI shows it and
    /// opens the browser), then poll with the provider's interval until the user
    /// approves. Honors `slow_down` by widening the interval, and stops with
    /// `.expired` once the grant's lifetime is used up.
    public func authorize(scopes: [String], onPrompt: @Sendable (DeviceCodeGrant) -> Void) async throws -> String {
        let grant = try await requestDeviceCode(scopes: scopes)
        onPrompt(grant)

        var interval = Double(max(1, grant.interval))
        var elapsed = 0.0

        while elapsed <= Double(grant.expiresIn) {
            try await sleeper.sleep(seconds: interval)
            elapsed += interval

            switch try await poll(grant) {
            case .authorized(let token):
                return token
            case .pending:
                continue
            case .slowDown:
                // GitHub asks us to add at least 5 seconds to the interval.
                interval += 5
            case .denied:
                throw AuthError.denied
            case .expired:
                throw AuthError.expired
            case .error(let message):
                throw AuthError.provider(message)
            }
        }
        throw AuthError.expired
    }
}
