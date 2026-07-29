import XCTest
@testable import KujtoAgents

/// The plan is what makes subscription to Vertex a one-tap switch, so its
/// contents are pinned exactly: the right variables set, and every variable the
/// previous account used cleared.
final class EnvironmentPlanTests: XCTestCase {
    private let planner = EnvironmentPlanner()

    private func vertex() -> AccountProfile {
        AccountProfile(id: "v", label: "Work Vertex", vendor: .claude, authMode: .vertex,
                       settings: ["vertexProject": "acme-prod", "vertexRegion": "us-east5"])
    }

    func testVertexSetsRoutingVariables() {
        let plan = planner.plan(for: vertex())
        XCTAssertEqual(plan.set["CLAUDE_CODE_USE_VERTEX"], "1")
        XCTAssertEqual(plan.set["ANTHROPIC_VERTEX_PROJECT_ID"], "acme-prod")
        XCTAssertEqual(plan.set["CLOUD_ML_REGION"], "us-east5")
    }

    func testVertexClearsBedrockAndApiKey() {
        let plan = planner.plan(for: vertex())
        XCTAssertTrue(plan.unset.contains("CLAUDE_CODE_USE_BEDROCK"))
        XCTAssertTrue(plan.unset.contains("AWS_REGION"))
        XCTAssertTrue(plan.unset.contains("ANTHROPIC_API_KEY"))
    }

    func testSubscriptionClearsEverything() {
        // The reverse switch: going back to a subscription must leave no cloud
        // routing behind, or the user keeps billing the wrong account.
        let profile = AccountProfile(id: "s", label: "Personal", vendor: .claude, authMode: .subscription)
        let plan = planner.plan(for: profile)
        XCTAssertTrue(plan.set.isEmpty)
        XCTAssertTrue(plan.unset.contains("CLAUDE_CODE_USE_VERTEX"))
        XCTAssertTrue(plan.unset.contains("ANTHROPIC_VERTEX_PROJECT_ID"))
        XCTAssertTrue(plan.unset.contains("CLOUD_ML_REGION"))
    }

    func testBedrockSetsRegionAndClearsVertex() {
        let profile = AccountProfile(id: "b", label: "AWS", vendor: .claude, authMode: .bedrock,
                                     settings: ["awsRegion": "us-west-2"])
        let plan = planner.plan(for: profile)
        XCTAssertEqual(plan.set["CLAUDE_CODE_USE_BEDROCK"], "1")
        XCTAssertEqual(plan.set["AWS_REGION"], "us-west-2")
        XCTAssertTrue(plan.unset.contains("CLAUDE_CODE_USE_VERTEX"))
    }

    func testApiKeyPlanCarriesPlaceholderNotSecret() {
        let profile = AccountProfile(id: "k", label: "Key", vendor: .claude, authMode: .apiKey)
        let plan = planner.plan(for: profile)
        XCTAssertEqual(plan.set["ANTHROPIC_API_KEY"], AccountSecretPlaceholder.value)
    }

    func testCustomVariableNamesAreHonored() {
        // The names are config so a vendor rename is not a code change.
        let names = EnvironmentPlanner.VariableNames(useVertex: "X_USE_VERTEX",
                                                     vertexProject: "X_PROJECT",
                                                     vertexRegion: "X_REGION")
        let plan = EnvironmentPlanner(names: names).plan(for: vertex())
        XCTAssertEqual(plan.set["X_USE_VERTEX"], "1")
        XCTAssertEqual(plan.set["X_PROJECT"], "acme-prod")
        XCTAssertNil(plan.set["CLAUDE_CODE_USE_VERTEX"])
    }

    func testShellLinesQuoteValues() {
        let plan = EnvironmentPlan(set: ["A": "one two"], unset: ["B"])
        XCTAssertEqual(plan.shellLines(), ["unset B", "export A='one two'"])
    }

    func testMissingSettingsBlockActivation() {
        let profile = AccountProfile(id: "v", label: "Half", vendor: .claude, authMode: .vertex,
                                     settings: ["vertexProject": "acme"])
        XCTAssertEqual(profile.missingSettings, ["vertexRegion"])
        XCTAssertFalse(profile.isReady)
    }
}
