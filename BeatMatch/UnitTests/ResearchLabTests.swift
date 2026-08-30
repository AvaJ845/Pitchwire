import XCTest
import SwiftData
@testable import Pitchwire

@MainActor
final class ResearchLabTests: XCTestCase {

    private func context() throws -> ModelContext {
        let schema = Schema([
            Story.self, Campaign.self, MediaTarget.self, Outlet.self,
            JournalistProfile.self, MatchExplanation.self, PitchDraft.self,
            EditorialEvidenceRecord.self, CoverageEvidence.self,
            FollowUpTask.self, RemovalRequest.self,
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return ModelContext(try ModelContainer(for: schema, configurations: [config]))
    }

    private func candidate(_ ctx: ModelContext, name: String = "Test J") -> JournalistProfile {
        let p = JournalistProfile(name: name, beatTopics: ["ai"],
                                  outlet: Outlet(name: "Outlet"), vertical: "ai-dev-tools")
        let r = EditorialEvidenceRecord(provenance: .publicEditorialSignal,
                                        evidenceSummary: "candidate", sourceURL: "https://x/author")
        p.evidenceRecords = [r]
        ctx.insert(p); ctx.insert(r); ctx.insert(p.outlet!)
        try? ctx.save()
        return p
    }

    func testSeedingIsIdempotent() throws {
        let ctx = try context()
        // No bundled seed in the test host → seeds from the fictional fallback.
        let first = JournalistDirectory.ensureSeeded(ctx)
        XCTAssertGreaterThan(first, 0)
        let second = JournalistDirectory.ensureSeeded(ctx)
        XCTAssertEqual(first, second, "ensureSeeded must be a no-op when the directory is populated")
    }

    func testVerifyRequiresAnArticleAndAReviewer() throws {
        let ctx = try context()
        let p = candidate(ctx)

        XCTAssertFalse(LabActions.verify(p, reviewer: "DJ", confidence: .moderate, context: ctx),
                       "no articles → cannot verify")
        XCTAssertEqual(p.evidenceState, .candidate)

        XCTAssertTrue(LabActions.addArticle(to: p, title: "A real piece",
                                            url: "https://x/a", publishedAt: Date(),
                                            topics: ["ai"], context: ctx))
        XCTAssertFalse(LabActions.verify(p, reviewer: "  ", confidence: .moderate, context: ctx),
                       "no reviewer → cannot verify")

        XCTAssertTrue(LabActions.verify(p, reviewer: "DJ", confidence: .high, context: ctx))
        XCTAssertTrue(p.isVerified)
        XCTAssertEqual(p.evidenceState, .verified)
        XCTAssertEqual(p.primaryEvidence?.verifiedBy, "DJ")
        XCTAssertEqual(p.evidenceConfidence, .high, "a fresh human verification unlocks stated confidence")
    }

    func testAddArticleRejectsNonHTTPS() throws {
        let ctx = try context()
        let p = candidate(ctx)
        XCTAssertFalse(LabActions.addArticle(to: p, title: "x", url: "http://insecure",
                                             publishedAt: nil, topics: [], context: ctx))
        XCTAssertFalse(LabActions.addArticle(to: p, title: "", url: "https://x/a",
                                             publishedAt: nil, topics: [], context: ctx))
        XCTAssertTrue(p.allCoverage.isEmpty)
    }

    func testUnverifyReturnsToCandidate() throws {
        let ctx = try context()
        let p = candidate(ctx)
        _ = LabActions.addArticle(to: p, title: "a", url: "https://x/a", publishedAt: nil, topics: [], context: ctx)
        _ = LabActions.verify(p, reviewer: "DJ", confidence: .moderate, context: ctx)
        LabActions.unverify(p, context: ctx)
        XCTAssertFalse(p.isVerified)
        XCTAssertEqual(p.evidenceState, .candidate)
    }

    func testRejectedProfileIsExcludedFromMatching() throws {
        let ctx = try context()
        let keep = candidate(ctx, name: "Keeper")
        let drop = candidate(ctx, name: "Dropped")
        LabActions.reject(drop, context: ctx)

        XCTAssertEqual(drop.evidenceState, .rejected)
        let matchable = JournalistDirectory.matchable(ctx).map(\.name)
        XCTAssertTrue(matchable.contains("Keeper"))
        XCTAssertFalse(matchable.contains("Dropped"))

        LabActions.restore(drop, context: ctx)
        XCTAssertTrue(JournalistDirectory.matchable(ctx).map(\.name).contains("Dropped"))
    }

    func testRemovalRequestRoundTrip() throws {
        let ctx = try context()
        let p = candidate(ctx)
        let req = RemovalRequest(journalistName: p.name, journalistID: p.id, reason: "test")
        ctx.insert(req)
        try ctx.save()
        XCTAssertTrue(req.isOpen)

        LabActions.resolveRemoval(req, resolution: "Rejected in review", context: ctx)
        XCTAssertFalse(req.isOpen)
        XCTAssertEqual(req.resolution, "Rejected in review")
    }

    func testMarkClaimedSetsProvenanceAndReviewer() throws {
        let ctx = try context()
        let p = candidate(ctx)
        LabActions.markClaimed(p, reviewer: "DJ", context: ctx)
        XCTAssertEqual(p.primaryEvidence?.provenance, .claimedProfile)
        XCTAssertEqual(p.primaryEvidence?.verifiedBy, "DJ")
    }

    func testMatchRunnerUsesTheDirectoryAndSharesJournalists() throws {
        let ctx = try context()
        JournalistDirectory.ensureSeeded(ctx)
        let dirCount = try ctx.fetchCount(FetchDescriptor<JournalistProfile>())

        let story = Story(rawText: "Launching an AI SDK for small teams today.")
        story.apply(StoryAnalysisResult(theme: "AI", vertical: "ai", region: "US",
                                        angle: "product launch", urgency: "standard", summary: "",
                                        audience: "Developers", subtopics: ["ai", "developer tools"], mediaHooks: []))
        let campaign = Campaign(name: "C", story: story)
        ctx.insert(campaign); ctx.insert(story)

        MatchRunner.populateTargets(for: campaign, context: ctx)
        XCTAssertFalse(campaign.mediaTargets.isEmpty)
        // Matching must not have grown the directory (journalists are shared).
        XCTAssertEqual(try ctx.fetchCount(FetchDescriptor<JournalistProfile>()), dirCount)

        // Re-run is clean — same directory count, targets rebuilt.
        MatchRunner.populateTargets(for: campaign, context: ctx)
        XCTAssertEqual(try ctx.fetchCount(FetchDescriptor<JournalistProfile>()), dirCount)
    }
}
