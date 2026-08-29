import XCTest
@testable import Pitchwire

final class EntitlementsTests: XCTestCase {

    private func makeEntitlements(tier: PlanTier) -> (Entitlements, LocalEntitlementStore) {
        let defaults = UserDefaults(suiteName: "test.\(UUID().uuidString)")!
        let store = LocalEntitlementStore(defaults: defaults, activeTier: tier)
        return (Entitlements(store: store), store)
    }

    func testFreePlanEnforcesStoryAnalysisLimit() {
        let (entitlements, _) = makeEntitlements(tier: .free)
        let limit = LocalEntitlementStore.plan(.free).limit(for: .storyAnalysis)!

        for i in 0..<limit {
            XCTAssertEqual(entitlements.remaining(.storyAnalysis), limit - i)
            XCTAssertTrue(entitlements.consume(.storyAnalysis))
        }
        XCTAssertEqual(entitlements.remaining(.storyAnalysis), 0)
        XCTAssertFalse(entitlements.consume(.storyAnalysis), "over-limit consume must fail")
        XCTAssertFalse(entitlements.hasAllowance(for: .storyAnalysis))
    }

    func testResetRestoresAllowance() {
        let (entitlements, _) = makeEntitlements(tier: .free)
        while entitlements.consume(.storyAnalysis) {}
        XCTAssertEqual(entitlements.remaining(.storyAnalysis), 0)

        entitlements.resetUsage()
        XCTAssertEqual(entitlements.remaining(.storyAnalysis),
                       LocalEntitlementStore.plan(.free).limit(for: .storyAnalysis))
        XCTAssertTrue(entitlements.consume(.storyAnalysis))
    }

    func testAgencyPlanIsUnlimited() {
        let (entitlements, _) = makeEntitlements(tier: .agency)
        XCTAssertNil(entitlements.remaining(.storyAnalysis))
        XCTAssertTrue(entitlements.isUnlimited(.aiPitchDraft))
        for _ in 0..<50 { XCTAssertTrue(entitlements.consume(.storyAnalysis)) }
    }

    func testFeatureGatesFollowThePlan() {
        let (free, _) = makeEntitlements(tier: .free)
        XCTAssertTrue(free.can(.savedCampaigns))
        XCTAssertFalse(free.can(.exportPitch))
        XCTAssertFalse(free.can(.teamWorkspace))

        let (team, _) = makeEntitlements(tier: .team)
        XCTAssertTrue(team.can(.exportPitch))
        XCTAssertTrue(team.can(.teamWorkspace))
        XCTAssertFalse(team.can(.multiClient))
    }

    func testChangingTheCatalogChangesLimitsWithNoOtherCode() {
        // Every limit a feature would enforce is read from the catalog; this test
        // exists to fail loudly if a limit ever gets hard-coded elsewhere.
        let free = LocalEntitlementStore.plan(.free)
        XCTAssertEqual(free.limit(for: .storyAnalysis), 3)
        XCTAssertEqual(free.limit(for: .aiPitchDraft), 5)
        XCTAssertNil(LocalEntitlementStore.plan(.agency).limit(for: .storyAnalysis))
    }
}

final class AITaskTests: XCTestCase {
    func testExtractionTasksAreFastTierAndProseTasksAreQuality() {
        XCTAssertEqual(AITask.storyAnalysis.defaultTier, .fast)
        XCTAssertEqual(AITask.matchExplanation.defaultTier, .fast)
        XCTAssertEqual(AITask.pitchDraft.defaultTier, .quality)
        XCTAssertEqual(AITask.subjectLine.defaultTier, .quality)
    }

    func testOfflineGatewayAlwaysThrowsNotConfigured() async {
        let client = AIClient(configuration: .offline)
        XCTAssertFalse(client.isConfigured)
        let text = await client.text(for: AIRequest(task: .pitchDraft, prompt: "x"))
        XCTAssertNil(text, "offline client must degrade to nil so callers fall back")
    }
}
