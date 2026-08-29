import XCTest
@testable import Pitchwire

final class SampleDataTests: XCTestCase {

    private let pool = SampleJournalists.seedPool()

    func testEveryProfileIsHonestlyMarkedAsSample() {
        XCTAssertFalse(pool.isEmpty)
        for j in pool {
            XCTAssertTrue(j.isSampleData, "\(j.name) must read as sample data")
            XCTAssertTrue(j.provenanceRecords.allSatisfy { $0.sourceType == .sampleData })
            XCTAssertEqual(j.evidenceConfidence, .exploratory,
                           "sample data must never present as high/moderate confidence")
        }
    }

    func testSampleProfilesAreWellFormed() {
        for j in pool {
            XCTAssertFalse(j.name.trimmingCharacters(in: .whitespaces).isEmpty)
            XCTAssertFalse(j.beatTopics.isEmpty, "\(j.name) has no beat topics")
            XCTAssertNotNil(j.outlet)
            XCTAssertFalse(j.recentBylineTitles.isEmpty, "\(j.name) has no bylines")
            for record in j.provenanceRecords {
                XCTAssertLessThanOrEqual(record.lastVerifiedAt, Date(), "verification date in the future")
                XCTAssertTrue(record.detail.lowercased().contains("not a real")
                              || record.detail.lowercased().contains("fictional"),
                              "sample provenance must say it isn't real")
            }
        }
    }

    func testMatchingReturnsOnlySampleProfiles() {
        let results = WeightedRelevanceService().match(analysis: Self.aiLaunch, against: pool)
        XCTAssertFalse(results.isEmpty)
        XCTAssertTrue(results.allSatisfy { $0.journalist.isSampleData })
    }

    static let aiLaunch = StoryAnalysisResult(
        theme: "AI", vertical: "ai", region: "US", angle: "product launch",
        urgency: "standard", summary: "", audience: "Developers",
        subtopics: ["developer tools", "apis"], mediaHooks: []
    )
}
