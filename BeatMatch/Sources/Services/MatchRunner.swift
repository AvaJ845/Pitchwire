import Foundation
import SwiftData

/// Turns a campaign's analyzed story into persisted `MediaTarget`s.
/// Shared by the first run and any re-run after the user edits the story tags.
@MainActor
enum MatchRunner {
    static func populateTargets(
        for campaign: Campaign,
        context: ModelContext,
        service: MatchingService = WeightedRelevanceService()
    ) {
        guard let story = campaign.story else { return }

        // Re-runnable: clear any targets from a previous pass.
        for target in campaign.mediaTargets { context.delete(target) }
        campaign.mediaTargets.removeAll()

        let pool = SampleJournalists.seedPool()
        let candidates = service.match(analysis: story.analysisResult, against: pool)

        for candidate in candidates {
            context.insert(candidate.journalist)
            if let outlet = candidate.journalist.outlet { context.insert(outlet) }
            for record in candidate.journalist.provenanceRecords { context.insert(record) }
            context.insert(candidate.explanation)

            let target = MediaTarget(
                confidenceTier: candidate.confidenceTier,
                confidenceScore: candidate.confidenceScore,
                journalist: candidate.journalist,
                explanation: candidate.explanation
            )
            target.campaign = campaign
            campaign.mediaTargets.append(target)
        }
    }
}
