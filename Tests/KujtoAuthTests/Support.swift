import Foundation
@testable import KujtoAuth

/// A transport that answers from an injected handler and records every request,
/// so tests can assert on both the responses returned and the calls made. The
/// handler may capture a `Counter` to script a sequence (pending then
/// authorized, for example).
final class MockTransport: HTTPTransport, @unchecked Sendable {
    private let handler: @Sendable (HTTPRequest) -> HTTPResponse
    private let lock = NSLock()
    private(set) var requests: [HTTPRequest] = []

    init(handler: @escaping @Sendable (HTTPRequest) -> HTTPResponse) {
        self.handler = handler
    }

    func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        lock.lock()
        requests.append(request)
        lock.unlock()
        return handler(request)
    }

    var paths: [String] { requests.map { $0.url.path } }
    func requestCount(pathSuffix: String, method: String) -> Int {
        requests.filter { $0.url.path.hasSuffix(pathSuffix) && $0.method == method }.count
    }
}

/// A sleeper that records the requested durations and returns immediately, so
/// device-flow polling tests run instantly and can assert on the backoff.
final class RecordingSleeper: AuthSleeper, @unchecked Sendable {
    private let lock = NSLock()
    private(set) var slept: [Double] = []

    func sleep(seconds: Double) async throws {
        lock.lock()
        slept.append(seconds)
        lock.unlock()
    }
}

/// A mutable counter a `@Sendable` handler can capture to script a sequence.
final class Counter: @unchecked Sendable {
    private let lock = NSLock()
    private var value = 0
    func next() -> Int {
        lock.lock(); defer { lock.unlock() }
        let current = value
        value += 1
        return current
    }
}

enum Sample {
    static func repoJSON(fullName: String = "ada/kujto-memory") -> [String: Any] {
        [
            "full_name": fullName,
            "clone_url": "https://github.com/\(fullName).git",
            "ssh_url": "git@github.com:\(fullName).git",
            "private": true
        ]
    }
}
