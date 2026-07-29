import XCTest
@testable import KujtoAgents

final class ModelPricingTests: XCTestCase {
    func testExactMatch() {
        let rate = ModelPricing.builtIn.rate(for: "claude-sonnet-4")
        XCTAssertNotNil(rate)
        XCTAssertEqual(rate?.input, 3)
        XCTAssertEqual(rate?.output, 15)
    }

    func testPrefixMatchWithSuffix() {
        let rate = ModelPricing.builtIn.rate(for: "claude-opus-4-20260115")
        XCTAssertNotNil(rate)
        XCTAssertEqual(rate?.input, 5)
    }

    func testUnknownModelReturnsNil() {
        XCTAssertNil(ModelPricing.builtIn.rate(for: "gpt-4o"))
    }

    func testCostCalculation() {
        let usage = SessionUsage(
            sessionID: "s1",
            timestamp: Date(),
            model: "claude-sonnet-4",
            inputTokens: 1_000_000,
            outputTokens: 500_000,
            cacheReadTokens: 200_000,
            cacheWriteTokens: 100_000)
        let cost = ModelPricing.builtIn.cost(of: usage)
        XCTAssertNotNil(cost)
        // input: 1M * 3/1M = 3.00
        // output: 0.5M * 15/1M = 7.50
        // cacheRead: 0.2M * 3/1M * 0.1 = 0.06
        // cacheWrite: 0.1M * 3/1M * 1.25 = 0.375
        XCTAssertEqual(cost!, 10.935, accuracy: 0.001)
    }

    func testUnknownModelCostIsNil() {
        let usage = SessionUsage(
            sessionID: "s1", timestamp: Date(), model: "llama-3",
            inputTokens: 1000, outputTokens: 500)
        XCTAssertNil(ModelPricing.builtIn.cost(of: usage))
    }

    func testLoadMergesOverrides() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("kujto-pricing-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let overrides = """
        {"custom-model": {"input": 99, "output": 199}}
        """
        try overrides.write(to: root.appendingPathComponent("pricing.json"),
                            atomically: true, encoding: .utf8)

        let pricing = ModelPricing.load(root: root)
        XCTAssertNotNil(pricing.rate(for: "claude-sonnet-4"), "built-in preserved")
        XCTAssertEqual(pricing.rate(for: "custom-model")?.input, 99)
    }
}
