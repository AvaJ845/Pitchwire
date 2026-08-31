import XCTest
import SwiftData
@testable import Pitchwire

@MainActor
final class FollowUpTests: XCTestCase {

    private func makeContext() throws -> ModelContext {
        let schema = Schema([
            Story.self, Campaign.self, MediaTarget.self, Outlet.self,
            JournalistProfile.self, MatchExplanation.self, PitchDraft.self,
            EditorialEvidenceRecord.self, CoverageEvidence.self, FollowUpTask.self,
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return ModelContext(try ModelContainer(for: schema, configurations: [config]))
    }

    func testFollowUpBelongsToCampaignAndCascadeDeletes() throws {
        let ctx = try makeContext()
        let campaign = Campaign(name: "Launch")
        ctx.insert(campaign)
        let task = FollowUpTask(title: "Nudge Dana", dueDate: .now, campaign: campaign)
        ctx.insert(task)
        campaign.followUpTasks.append(task)
        try ctx.save()

        XCTAssertEqual(campaign.followUpTasks.count, 1)
        XCTAssertFalse(campaign.followUpTasks[0].isDone)

        ctx.delete(campaign)
        try ctx.save()
        let remaining = try ctx.fetch(FetchDescriptor<FollowUpTask>())
        XCTAssertTrue(remaining.isEmpty, "follow-ups cascade-delete with their campaign")
    }

    func testOpenCountDrivesTheHomeNudge() throws {
        let ctx = try makeContext()
        let campaign = Campaign(name: "Launch")
        ctx.insert(campaign)
        let overdue = FollowUpTask(title: "a", dueDate: .now.addingTimeInterval(-3600), campaign: campaign)
        let future = FollowUpTask(title: "b", dueDate: .now.addingTimeInterval(10 * 86_400), campaign: campaign)
        let done = FollowUpTask(title: "c", dueDate: .now, campaign: campaign)
        done.isDone = true
        for t in [overdue, future, done] { ctx.insert(t); campaign.followUpTasks.append(t) }
        try ctx.save()

        let due = campaign.followUpTasks.filter {
            !$0.isDone && ($0.dueDate.map { $0 < .now.addingTimeInterval(86_400) } ?? false)
        }
        XCTAssertEqual(due.map(\.title), ["a"], "only not-done tasks due within a day count")
    }
}

final class MatchExplanationTests: XCTestCase {
    func testKeepsGroundedReasonWhenAIEnhances() {
        let e = MatchExplanation(reasonText: "Covers AI — a direct fit.")
        XCTAssertEqual(e.groundedReason, e.reasonText)
        XCTAssertFalse(e.aiEnhanced)

        e.reasonText = "Riley has covered three AI-launch stories in the last month and prefers concrete data."
        e.aiEnhanced = true
        XCTAssertEqual(e.groundedReason, "Covers AI — a direct fit.", "the grounded original is preserved")
    }
}
