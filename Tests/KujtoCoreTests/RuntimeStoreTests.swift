import XCTest
@testable import KujtoCore

final class RuntimeStoreTests: XCTestCase {
    private var tmp: URL!

    override func setUpWithError() throws {
        tmp = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("kujto-runtime-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tmp)
    }

    private func makeApp(_ id: String) -> LaunchedApp {
        LaunchedApp(
            id: id,
            bundleId: "com.example.\(id)",
            processName: id,
            simulatorUdid: "UDID-\(id)",
            appPath: "/tmp/\(id).app",
            launchedAt: "2026-06-12T12:00:00Z"
        )
    }

    func testAppendListFindRemoveRoundTrip() throws {
        let store = RuntimeStore(root: tmp)
        XCTAssertEqual(try store.list().count, 0)

        try store.append(makeApp("alpha"))
        try store.append(makeApp("beta"))
        XCTAssertEqual(try store.list().count, 2)
        XCTAssertEqual(try store.find(id: "beta")?.bundleId, "com.example.beta")

        let removed = try store.remove(id: "alpha")
        XCTAssertEqual(removed?.id, "alpha")
        XCTAssertEqual(try store.list().count, 1)

        let missing = try store.remove(id: "zzz")
        XCTAssertNil(missing)
    }
}
