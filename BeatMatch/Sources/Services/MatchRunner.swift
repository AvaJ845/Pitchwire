import Foundation
import SwiftData

/// Turns a campaign's analyzed story into persisted `MediaTarget`s.
/// Shared by the first run and any re-run after the user edits the story tags.
@MainActor
enum MatchRunner {
    static func populateTargets(
        for campaign: Campaign,
        context: ModelContext,
        service: MatchingService = WeightedRelevanceService(),
        embeddings: EmbeddingProvider? = DefaultEmbeddingProvider.make()
    ) {
        guard let story = campaign.story else { return }

        // Re-runnable: clear this campaign's targets (and their explanations).
        // Journalists live in the shared directory — never touched here.
        for target in campaign.mediaTargets {
            if let explanation = target.explanation { context.delete(explanation) }
            context.delete(target)
        }
        campaign.mediaTargets.removeAll()

        JournalistDirectory.ensureSeeded(context)
        let pool = JournalistDirectory.matchable(context)

        // Warm the on-device semantic vectors for anyone missing one — a first
        // run, an edited profile, or a vector from a previous model (dimension
        // mismatch). Cached on the model afterwards.
        if let embeddings {
            var wroteVector = false
            for journalist in pool where journalist.embedding.count != MiniLMEmbeddingProvider.dimension {
                if let v = embeddings.vector(for: journalist.embeddingText),
                   v.count == MiniLMEmbeddingProvider.dimension {
                    journalist.embedding = v
                    wroteVector = true
                }
            }
            if wroteVector { try? context.save() }
        }

        let candidates = service.match(
            analysis: story.analysisResult, storyText: story.rawText,
            against: pool, embeddings: embeddings)

        for candidate in candidates {
            context.insert(candidate.explanation)   // one per (campaign, journalist), rebuilt each run

            let target = MediaTarget(
                confidenceTier: candidate.confidenceTier,
                confidenceScore: candidate.confidenceScore,
                journalist: candidate.journalist,   // an existing directory record
                explanation: candidate.explanation
            )
            target.campaign = campaign
            campaign.mediaTargets.append(target)
        }
    }
}
