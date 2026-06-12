import XCTest
@testable import KujtoCore

final class UISessionTests: XCTestCase {
    private var tmp: URL!

    override func setUpWithError() throws {
        tmp = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("kujto-ui-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tmp)
    }

    func testWriteAndReadSession() throws {
        let client = UISessionClient(directory: tmp)
        let s = UISessionClient.Session(id: "ui_x", runnerPid: 4242, bundleId: "com.example.App", startedAt: "2026-06-12T12:00:00Z")
        try client.writeSession(s)
        let round = try client.readSession()
        XCTAssertEqual(round?.id, "ui_x")
        XCTAssertEqual(round?.runnerPid, 4242)
        XCTAssertEqual(round?.bundleId, "com.example.App")
    }

    func testNextSeqIncrements() throws {
        let client = UISessionClient(directory: tmp)
        XCTAssertEqual(try client.nextSeq(), 1)
        // Simulate that command 1 was submitted by writing the file.
        let cmdURL = tmp.appendingPathComponent("cmd-1.json")
        try Data().write(to: cmdURL)
        XCTAssertEqual(try client.nextSeq(), 2)

        let cmd5 = tmp.appendingPathComponent("cmd-5.json")
        try Data().write(to: cmd5)
        XCTAssertEqual(try client.nextSeq(), 6)
    }

    func testSubmitTimesOutWhenNoRunner() throws {
        let client = UISessionClient(directory: tmp)
        let cmd = UICommand(seq: 1, action: .tap)
        XCTAssertThrowsError(try client.submit(cmd, timeoutMs: 150)) { error in
            guard let kj = error as? KujtoError else { return XCTFail("not a KujtoError") }
            XCTAssertEqual(kj.code, .timeout)
        }
    }
}
