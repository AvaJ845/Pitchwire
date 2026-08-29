import XCTest
@testable import Pitchwire

final class RelevanceEngineTests: XCTestCase {

    private func analysis(
        vertical: String = "ai",
        angle: String = "product launch",
        audience: String = "Developers",
        region: String = "US",
        subtopics: [String] = ["developer tools", "apis"]
    ) -> StoryAnalysisResult {
        StoryAnalysisResult(
            theme: vertical.capitalized, vertical: vertical, region: region, angle: angle,
            urgency: "standard", summary: "", audience: audience, subtopics: subtopics, mediaHooks: []
        )
    }

    private func journalist(
        topics: [String] = ["ai", "developer tools"],
        bylines: [String] = ["The API-first AI stack"],
        audiences: [String] = ["Developers"],
        regions: [String] = ["US"],
        angles: [String] = ["product launch"],
        doNotPitch: [String] = []
    ) -> JournalistProfile {
        let j = JournalistProfile(name: "Test J", beatTopics: topics, recentBylineTitles: bylines,
                                  audiences: audiences, regions: regions, coveredAngles: angles, doNotPitch: doNotPitch)
        j.provenanceRecords = [ProvenanceRecord(sourceType: .sampleData, detail: "not a real person")]
        return j
    }

    func testAllSignalsAligningProducesAnExcellentTier() {
        let r = RelevanceEngine.score(analysis: analysis(), journalist: journalist())
        XCTAssertGreaterThan(r.total, 0.68)
        XCTAssertEqual(r.tier, .excellent)
        XCTAssertFalse(r.drivers.isEmpty, "an excellent match must have explainable drivers")
    }

    func testOffTopicJournalistScoresLow() {
        let j = journalist(topics: ["fashion", "food"], bylines: ["The best restaurants of 2026"],
                           audiences: ["Consumers"], angles: ["general news"])
        let r = RelevanceEngine.score(analysis: analysis(), journalist: j)
        XCTAssertLessThan(r.total, 0.42)
    }

    func testDeclaredPitchPreferenceDisqualifies() {
        let j = journalist(angles: ["funding"], doNotPitch: ["product launch"])
        let r = RelevanceEngine.score(analysis: analysis(angle: "product launch"), journalist: j)
        XCTAssertTrue(r.isDisqualified)
        let prose = RelevanceEngine.prose(r, journalist: j)
        XCTAssertTrue(prose.lowercased().contains("asked not to be pitched"))
    }

    func testRecentCoverageOnTopicLiftsTheScore() {
        let withCoverage = journalist(bylines: ["Why every AI startup needs an SDK strategy"])
        let withoutCoverage = journalist(bylines: ["A history of the fax machine"])
        let a = analysis(subtopics: ["sdk", "ai"])
        XCTAssertGreaterThan(
            RelevanceEngine.score(analysis: a, journalist: withCoverage).total,
            RelevanceEngine.score(analysis: a, journalist: withoutCoverage).total
        )
    }

    func testProseIsGroundedInTheDrivingSignals() {
        let r = RelevanceEngine.score(analysis: analysis(), journalist: journalist())
        let prose = RelevanceEngine.prose(r, journalist: journalist())
        XCTAssertFalse(prose.isEmpty)
        // must reference at least one real signal, not a generic filler
        XCTAssertTrue(prose.contains("cover") || prose.contains("wrote") || prose.contains("beat") || prose.contains("writes"))
    }

    func testWeightsSumToOne() {
        let r = RelevanceEngine.score(analysis: analysis(), journalist: journalist())
        XCTAssertEqual(r.signals.map(\.weight).reduce(0, +), 1.0, accuracy: 0.001)
    }
}
