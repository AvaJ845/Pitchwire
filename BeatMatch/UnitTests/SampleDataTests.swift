import XCTest
@testable import Pitchwire

/// The fictional fallback pool must be unmistakably fictional at every level.
final class SampleDataTests: XCTestCase {

    private let pool = SampleJournalists.seedPool()

    func testEveryProfileIsHonestlyMarkedAsDemo() {
        XCTAssertFalse(pool.isEmpty)
        for j in pool {
            XCTAssertTrue(j.isFictional, "\(j.name) must read as fictional demo data")
            XCTAssertFalse(j.isVerified)
            XCTAssertFalse(j.isUnverifiedCandidate, "fictional data is not a 'candidate'")
            XCTAssertTrue(j.evidenceRecords.allSatisfy { $0.provenance == .fictionalSample })
            XCTAssertEqual(j.evidenceConfidence, .exploratory,
                           "demo data must never present as high/moderate confidence")
            XCTAssertEqual(j.evidenceState, .demo)
        }
    }

    func testDemoProfilesAreWellFormed() {
        for j in pool {
            XCTAssertFalse(j.name.trimmingCharacters(in: .whitespaces).isEmpty)
            XCTAssertFalse(j.beatTopics.isEmpty, "\(j.name) has no beat topics")
            XCTAssertNotNil(j.outlet)
            XCTAssertFalse(j.recentBylineTitles.isEmpty, "\(j.name) has no coverage")
            for record in j.evidenceRecords {
                XCTAssertNil(record.verificationDate, "demo data must not carry a verification date")
                XCTAssertTrue(record.evidenceSummary.lowercased().contains("not a real")
                              || record.evidenceSummary.lowercased().contains("fictional"),
                              "demo provenance must say it isn't real")
                for article in record.articles {
                    XCTAssertTrue(article.url.isEmpty, "demo articles have nothing real to open")
                    if let d = article.publishedAt { XCTAssertLessThanOrEqual(d, Date()) }
                }
            }
        }
    }

    func testMatchingReturnsOnlyDemoProfiles() {
        let results = WeightedRelevanceService().match(analysis: Self.aiLaunch, against: pool)
        XCTAssertFalse(results.isEmpty)
        XCTAssertTrue(results.allSatisfy { $0.journalist.isFictional })
    }

    /// With no seed file bundled in the test host, the loader must fall back.
    func testSeedLoaderFallsBackToDemoWhenNoFileBundled() {
        let loaded = EditorialSeedLoader.seedPool()
        XCTAssertFalse(loaded.isEmpty)
        // Test host has no editorial_seed.json → same as the demo pool.
        XCTAssertEqual(loaded.count, pool.count)
    }

    static let aiLaunch = StoryAnalysisResult(
        theme: "AI", vertical: "ai", region: "US", angle: "product launch",
        urgency: "standard", summary: "", audience: "Developers",
        subtopics: ["developer tools", "apis"], mediaHooks: []
    )
}
