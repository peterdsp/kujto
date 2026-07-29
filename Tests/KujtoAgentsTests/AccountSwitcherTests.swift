import XCTest
@testable import KujtoAgents

/// The switch itself: ordering, refusal cases, credential handling, and the
/// handoff note that makes the next account continuous rather than amnesiac.
final class AccountSwitcherTests: XCTestCase {

    /// Records what was applied so the test can assert on it, and can be made
    /// to fail on demand to prove the roster is not mutated on a failed apply.
    final class RecordingApplier: EnvironmentApplier, @unchecked Sendable {
        private let lock = NSLock()
        private(set) var applied: [EnvironmentPlan] = []
        private(set) var resolvedSecrets: [String] = []
        var shouldFail = false

        func apply(_ plan: EnvironmentPlan, secret: @Sendable () -> String?) throws {
            if shouldFail { throw AccountError.missingCredential("forced") }
            lock.lock(); defer { lock.unlock() }
            applied.append(plan)
            for (_, value) in plan.set where AccountSecretPlaceholder.isPlaceholder(value) {
                if let real = secret() { resolvedSecrets.append(real) }
            }
        }
    }

    private func roster() -> AccountRoster {
        AccountRoster(profiles: [
            AccountProfile(id: "personal", label: "Personal", vendor: .claude, authMode: .subscription),
            AccountProfile(id: "work", label: "Work Vertex", vendor: .claude, authMode: .vertex,
                           settings: ["vertexProject": "acme", "vertexRegion": "us-east5"]),
            AccountProfile(id: "half", label: "Incomplete", vendor: .claude, authMode: .vertex),
        ], activeID: "personal")
    }

    func testSwitchAppliesPlanAndRecordsActive() throws {
        let applier = RecordingApplier()
        var r = roster()
        let outcome = try AccountSwitcher(applier: applier)
            .activate("work", in: &r, timestamp: "2026-07-29T00:00:00Z")

        guard case let .switched(plan, _) = outcome else { return XCTFail("expected switched") }
        XCTAssertEqual(plan.set["CLAUDE_CODE_USE_VERTEX"], "1")
        XCTAssertEqual(r.activeID, "work")
        XCTAssertEqual(applier.applied.count, 1)
    }

    func testSwitchingToActiveIsNoOp() throws {
        let applier = RecordingApplier()
        var r = roster()
        let outcome = try AccountSwitcher(applier: applier)
            .activate("personal", in: &r, timestamp: "t")
        XCTAssertEqual(outcome, .alreadyActive)
        XCTAssertTrue(applier.applied.isEmpty)
    }

    func testIncompleteProfileIsRefusedBeforeApplying() throws {
        let applier = RecordingApplier()
        var r = roster()
        let outcome = try AccountSwitcher(applier: applier).activate("half", in: &r, timestamp: "t")
        XCTAssertEqual(outcome, .incomplete(missing: ["vertexProject", "vertexRegion"]))
        XCTAssertTrue(applier.applied.isEmpty, "nothing applied")
        XCTAssertEqual(r.activeID, "personal", "roster untouched")
    }

    func testUnknownProfile() throws {
        var r = roster()
        let outcome = try AccountSwitcher(applier: RecordingApplier())
            .activate("nope", in: &r, timestamp: "t")
        XCTAssertEqual(outcome, .unknownProfile)
    }

    func testFailedApplyLeavesRosterUnchanged() {
        let applier = RecordingApplier()
        applier.shouldFail = true
        var r = roster()
        XCTAssertThrowsError(try AccountSwitcher(applier: applier)
            .activate("work", in: &r, timestamp: "t"))
        XCTAssertEqual(r.activeID, "personal", "still on the old account")
    }

    func testSecretIsResolvedOnlyAtApplyTime() throws {
        let applier = RecordingApplier()
        var r = AccountRoster(profiles: [
            AccountProfile(id: "a", label: "A", vendor: .claude, authMode: .subscription),
            AccountProfile(id: "k", label: "Key", vendor: .openai, authMode: .apiKey),
        ], activeID: "a")

        let outcome = try AccountSwitcher(applier: applier)
            .activate("k", in: &r, timestamp: "t", secret: { "the-real-key" })

        guard case let .switched(plan, _) = outcome else { return XCTFail("expected switched") }
        // The plan itself never carries the credential.
        XCTAssertEqual(plan.set["ANTHROPIC_API_KEY"], AccountSecretPlaceholder.value)
        XCTAssertEqual(applier.resolvedSecrets, ["the-real-key"])
    }

    // MARK: Handoff

    func testHandoffNoteIsWrittenWithContext() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("kujto-handoff-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        var r = roster()
        let context = HandoffContext(repoName: "Syrmos", branch: "main",
                                     changedFiles: ["App/PaymentClient.swift"],
                                     activeRules: ["Payment audit"], riskTags: ["payment"],
                                     task: "Add refund flow",
                                     notes: ["Ruled out changing the schema"])

        let outcome = try AccountSwitcher(applier: RecordingApplier())
            .activate("work", in: &r, context: context, timestamp: "2026-07-29T10:00:00Z",
                      handoffRoot: root)

        guard case let .switched(_, path) = outcome, let path else {
            return XCTFail("expected a handoff path")
        }
        let text = try String(contentsOfFile: path, encoding: .utf8)
        // The next account gets the switch, the work, the rules, and the risk.
        XCTAssertTrue(text.contains("From: Personal"))
        XCTAssertTrue(text.contains("To: Work Vertex"))
        XCTAssertTrue(text.contains("Add refund flow"))
        XCTAssertTrue(text.contains("App/PaymentClient.swift"))
        XCTAssertTrue(text.contains("Payment audit"))
        XCTAssertTrue(text.contains("payment"))
        XCTAssertTrue(text.contains("Ruled out changing the schema"))
        // It lands where every agent is already told to look.
        XCTAssertTrue(path.hasSuffix("memory/handoff_active.md"))
    }

    func testHandoffOmitsEmptySections() {
        let text = HandoffWriter().render(
            from: nil,
            to: AccountProfile(id: "a", label: "A", vendor: .claude, authMode: .subscription),
            context: HandoffContext(), timestamp: "t")
        XCTAssertTrue(text.contains("From: none"))
        XCTAssertFalse(text.contains("## Files in play"))
        XCTAssertFalse(text.contains("## Risk"))
    }
}
