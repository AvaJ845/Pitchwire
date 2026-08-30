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

    /// Builds a fictional profile with article-level coverage. `bylines` become
    /// `CoverageEvidence` dated `daysAgo` back, tagged with `topics`.
    private func journalist(
        topics: [String] = ["ai", "developer tools"],
        bylines: [String] = ["The API-first AI stack", "Why developer tools keep winning"],
        articleTopics: [String]? = nil,
        daysAgo: Int = 20,
        audiences: [String] = ["Developers"],
        regions: [String] = ["US"],
        angles: [String] = ["product launch"],
        outletVerticals: [String] = ["ai", "developer tools"],
        doNotPitch: [String] = []
    ) -> JournalistProfile {
        let j = JournalistProfile(
            name: "Test J", beatTopics: topics,
            outlet: Outlet(name: "Test Outlet", verticals: outletVerticals),
            audiences: audiences, regions: regions, coveredAngles: angles, doNotPitch: doNotPitch
        )
        let when = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date())
        let record = EditorialEvidenceRecord(provenance: .fictionalSample, evidenceSummary: "not a real person")
        record.articles = bylines.map {
            CoverageEvidence(title: $0, url: "", publishedAt: when, topics: articleTopics ?? topics)
        }
        j.evidenceRecords = [record]
        return j
    }

    func testAllSignalsAligningProducesAnExcellentTier() {
        let r = RelevanceEngine.score(analysis: analysis(), journalist: journalist())
        XCTAssertGreaterThan(r.total, 0.68)
        XCTAssertEqual(r.tier, .excellent)
        XCTAssertFalse(r.drivers.isEmpty, "an excellent match must have explainable drivers")
    }

    func testOffTopicJournalistScoresLow() {
        let j = journalist(topics: ["fashion", "food"],
                           bylines: ["The best restaurants of 2026"],
                           audiences: ["Consumers"], angles: ["general news"],
                           outletVerticals: ["food", "lifestyle"])
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
        let withCoverage = journalist(bylines: ["Why every AI startup needs an SDK strategy"],
                                      articleTopics: ["sdk", "ai"])
        let withoutCoverage = journalist(bylines: ["A history of the fax machine"],
                                         articleTopics: ["hardware"])
        let a = analysis(subtopics: ["sdk", "ai"])
        XCTAssertGreaterThan(
            RelevanceEngine.score(analysis: a, journalist: withCoverage).total,
            RelevanceEngine.score(analysis: a, journalist: withoutCoverage).total
        )
    }

    func testRepeatedCoverageOutscoresAOneOff() {
        let a = analysis(subtopics: ["ai", "agents"])
        let oneOff = journalist(bylines: ["The year agents got useful"], articleTopics: ["ai", "agents"])
        let repeated = journalist(
            bylines: ["The year agents got useful", "How agent frameworks actually work", "Agents in production"],
            articleTopics: ["ai", "agents"]
        )
        XCTAssertGreaterThan(
            RelevanceEngine.score(analysis: a, journalist: repeated).total,
            RelevanceEngine.score(analysis: a, journalist: oneOff).total
        )
    }

    func testExcellentTierRequiresRepeatedCoverage() {
        let a = analysis()
        let oneStrongPiece = journalist(bylines: ["The API-first AI stack"])
        let r = RelevanceEngine.score(analysis: a, journalist: oneStrongPiece)
        XCTAssertNotEqual(r.tier, .excellent, "a single headline is at most a strong match")
    }

    func testStaleCoverageScoresBelowFreshCoverage() {
        let a = analysis(subtopics: ["ai", "apis"])
        let fresh = journalist(daysAgo: 15)
        let stale = journalist(daysAgo: 900)
        XCTAssertGreaterThan(
            RelevanceEngine.score(analysis: a, journalist: fresh).total,
            RelevanceEngine.score(analysis: a, journalist: stale).total
        )
    }

    func testPublicationRelevanceContributes() {
        let a = analysis()
        let onBeatOutlet = journalist(outletVerticals: ["ai", "developer tools"])
        let offBeatOutlet = journalist(outletVerticals: ["sports", "travel"])
        XCTAssertGreaterThan(
            RelevanceEngine.score(analysis: a, journalist: onBeatOutlet).total,
            RelevanceEngine.score(analysis: a, journalist: offBeatOutlet).total
        )
    }

    func testProseIsGroundedInTheDrivingSignals() {
        let r = RelevanceEngine.score(analysis: analysis(), journalist: journalist())
        let prose = RelevanceEngine.prose(r, journalist: journalist())
        XCTAssertFalse(prose.isEmpty)
        XCTAssertTrue(prose.contains("cover") || prose.contains("wrote") || prose.contains("beat")
                      || prose.contains("writes") || prose.contains("covered"))
    }

    func testRelevanceResultCarriesTheNotAPredictionDisclaimer() {
        let r = RelevanceEngine.score(analysis: analysis(), journalist: journalist())
        XCTAssertTrue(r.relevanceDisclaimer.lowercased().contains("not a prediction"))
    }

    func testWeightsSumToOne() {
        let r = RelevanceEngine.score(analysis: analysis(), journalist: journalist())
        XCTAssertEqual(r.signals.map(\.weight).reduce(0, +), 1.0, accuracy: 0.001)
    }
}
