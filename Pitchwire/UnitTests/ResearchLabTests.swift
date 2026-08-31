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
        _ = candidate(ctx, name: "Keeper")
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

    func testMatchRunnerUsesTheDirectoryAndSharesJournalists() async throws {
        let ctx = try context()
        JournalistDirectory.ensureSeeded(ctx)
        let dirCount = try ctx.fetchCount(FetchDescriptor<JournalistProfile>())

        let story = Story(rawText: "Launching an AI SDK for small teams today.")
        story.apply(StoryAnalysisResult(theme: "AI", vertical: "ai", region: "US",
                                        angle: "product launch", urgency: "standard", summary: "",
                                        audience: "Developers", subtopics: ["ai", "developer tools"], mediaHooks: []))
        let campaign = Campaign(name: "C", story: story)
        ctx.insert(campaign); ctx.insert(story)

        await MatchRunner.populateTargets(for: campaign, context: ctx)
        XCTAssertFalse(campaign.mediaTargets.isEmpty)
        // Matching must not have grown the directory (journalists are shared).
        XCTAssertEqual(try ctx.fetchCount(FetchDescriptor<JournalistProfile>()), dirCount)

        // Re-run is clean — same directory count, targets rebuilt.
        await MatchRunner.populateTargets(for: campaign, context: ctx)
        XCTAssertEqual(try ctx.fetchCount(FetchDescriptor<JournalistProfile>()), dirCount)
    }

    /// The detail view reads `MediaTarget.relevance`, not a recompute. That
    /// stored breakdown must be present and must be the one the score/tier came
    /// from — otherwise "How we scored this" shows numbers that don't add up to
    /// the ranking.
    func testMatchRunnerPersistsTheBreakdownBehindEachScore() async throws {
        let ctx = try context()
        JournalistDirectory.ensureSeeded(ctx)

        let story = Story(rawText: "Shipping end-to-end encrypted group calling with a third-party audit.")
        story.apply(StoryAnalysisResult(theme: "Privacy", vertical: "consumer", region: "US",
                                        angle: "product launch", urgency: "standard", summary: "",
                                        audience: "Consumers",
                                        subtopics: ["privacy", "encryption", "security"], mediaHooks: []))
        let campaign = Campaign(name: "C", story: story)
        ctx.insert(campaign); ctx.insert(story)
        await MatchRunner.populateTargets(for: campaign, context: ctx)

        let targets = campaign.mediaTargets
        XCTAssertFalse(targets.isEmpty)
        for t in targets {
            let breakdown = try XCTUnwrap(t.relevance, "\(t.journalist?.name ?? "?") has no stored breakdown")
            // The persisted breakdown reproduces the score and tier exactly.
            XCTAssertEqual(breakdown.total, t.confidenceScore, accuracy: 0.0001,
                           "stored signals don't reproduce the ranking score")
            XCTAssertEqual(breakdown.tier, t.confidenceTier)
            XCTAssertEqual(breakdown.signals.map(\.weight).reduce(0, +), 1.0, accuracy: 0.001)
        }
    }

    func testRelevanceResultSurvivesACodableRoundTrip() throws {
        let a = StoryAnalysisResult(theme: "AI", vertical: "ai", region: "US", angle: "funding",
                                    urgency: "standard", summary: "", audience: "Developers",
                                    subtopics: ["ai", "llm"], mediaHooks: [])
        let j = JournalistProfile(name: "J", beatTopics: ["ai", "llm"], outlet: Outlet(name: "O"))
        let original = RelevanceEngine.score(analysis: a, journalist: j, similarity: 0.62)

        let data = try JSONEncoder().encode(original)
        let restored = try JSONDecoder().decode(RelevanceResult.self, from: data)

        XCTAssertEqual(restored.total, original.total, accuracy: 0.0001)
        XCTAssertEqual(restored.tier, original.tier)
        XCTAssertEqual(restored.signals.map(\.name), original.signals.map(\.name))
        XCTAssertEqual(restored.signals.map(\.score), original.signals.map(\.score))
        // id is kind-derived, so it survives a decode unchanged (no phantom
        // ForEach churn on the score card).
        XCTAssertEqual(restored.signals.map(\.id), original.signals.map(\.id))
    }

    func testEmbeddingBlobRoundTripsThroughSwiftData() throws {
        let ctx = try context()
        let p = candidate(ctx)
        let vec = (0..<MiniLMEmbeddingProvider.dimension).map { Float($0) * 0.001 - 0.19 }
        p.embedding = vec
        try ctx.save()

        let refetched = try XCTUnwrap(
            try ctx.fetch(FetchDescriptor<JournalistProfile>()).first { $0.id == p.id })
        XCTAssertEqual(refetched.embedding.count, MiniLMEmbeddingProvider.dimension)
        XCTAssertEqual(refetched.embedding, vec)
        refetched.embedding = []
        XCTAssertTrue(refetched.embedding.isEmpty)
    }
}
