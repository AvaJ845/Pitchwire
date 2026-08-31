import XCTest
import SwiftData
@testable import Pitchwire

@MainActor
final class WorkspaceExporterTests: XCTestCase {

    private func context() throws -> ModelContext {
        let schema = Schema([
            Story.self, Campaign.self, MediaTarget.self, Outlet.self,
            JournalistProfile.self, MatchExplanation.self, PitchDraft.self,
            EditorialEvidenceRecord.self, CoverageEvidence.self,
            FollowUpTask.self, RemovalRequest.self, AuditEntry.self,
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return ModelContext(try ModelContainer(for: schema, configurations: [config]))
    }

    func testExportsCampaignsWithNoContactData() throws {
        let ctx = try context()
        let story = Story(rawText: "Launching an AI SDK today.")
        story.apply(StoryAnalysisResult(theme: "AI", vertical: "ai", region: "US", angle: "product launch",
                                        urgency: "standard", summary: "s", audience: "Developers",
                                        subtopics: ["ai"], mediaHooks: ["hook"]))
        let campaign = Campaign(name: "Launch", story: story)
        ctx.insert(story); ctx.insert(campaign)

        let j = JournalistProfile(name: "Test J", beatTopics: ["ai"], outlet: Outlet(name: "Outlet"))
        let explanation = MatchExplanation(reasonText: "covers AI — a solid fit")
        let target = MediaTarget(confidenceTier: .strong, confidenceScore: 0.55,
                                 journalist: j, explanation: explanation)
        target.campaign = campaign
        campaign.mediaTargets.append(target)
        ctx.insert(j); ctx.insert(explanation)

        let draft = PitchDraft(subject: "Hi", shortBody: "short", longBody: "long")
        draft.campaign = campaign
        campaign.pitchDrafts.append(draft)
        ctx.insert(draft)

        let task = FollowUpTask(title: "Nudge Test J", campaign: campaign)
        campaign.followUpTasks.append(task)
        ctx.insert(task)
        try ctx.save()

        let json = WorkspaceExporter.json(ctx)
        XCTAssertTrue(json.contains("\"name\" : \"Launch\""))
        XCTAssertTrue(json.contains("covers AI"))
        XCTAssertTrue(json.contains("Nudge Test J"))
        XCTAssertTrue(json.contains("Launching an AI SDK"))

        let lower = json.lowercased()
        for banned in ["\"email\"", "\"phone\"", "mailto:", "\"twitter\"", "\"linkedin\""] {
            XCTAssertFalse(lower.contains(banned), "workspace export must not carry \(banned)")
        }

        // Round-trips as valid JSON.
        XCTAssertNoThrow(try JSONSerialization.jsonObject(with: Data(json.utf8)))
    }
}
