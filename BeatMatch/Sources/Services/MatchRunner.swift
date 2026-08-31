import Foundation
import SwiftData

/// Turns a campaign's analyzed story into persisted `MediaTarget`s.
/// Shared by the first run and any re-run after the user edits the story tags.
@MainActor
enum MatchRunner {

    /// Compute and cache the on-device semantic vector for every directory
    /// profile that's missing one. The CPU-bound embedding pass runs **off the
    /// main actor**; only the SwiftData reads and writes touch it. Idempotent —
    /// a no-op once every profile is warm (which is the steady state after the
    /// first run or a model swap). Called at launch (background priority) and
    /// again just before a match run, so a fast user still gets vectors.
    @discardableResult
    static func warmDirectory(
        context: ModelContext,
        embeddings: EmbeddingProvider? = DefaultEmbeddingProvider.shared,
        priority: TaskPriority = .userInitiated
    ) async -> Int {
        guard let embeddings else { return 0 }

        let pool = JournalistDirectory.matchable(context)
        let pending: [(id: PersistentIdentifier, text: String)] = pool
            .filter { $0.embedding.count != MiniLMEmbeddingProvider.dimension }
            .map { ($0.persistentModelID, $0.embeddingText) }
        guard !pending.isEmpty else { return 0 }

        let warmed: [PersistentIdentifier: [Double]] = await Task.detached(priority: priority) {
            var out: [PersistentIdentifier: [Double]] = [:]
            for item in pending {
                if let v = embeddings.vector(for: item.text),
                   v.count == MiniLMEmbeddingProvider.dimension {
                    out[item.id] = v
                }
            }
            return out
        }.value

        var wrote = 0
        for journalist in pool {
            if let v = warmed[journalist.persistentModelID] {
                journalist.embedding = v
                wrote += 1
            }
        }
        if wrote > 0 { try? context.save() }
        return wrote
    }

    static func populateTargets(
        for campaign: Campaign,
        context: ModelContext,
        service: MatchingService = WeightedRelevanceService(),
        embeddings: EmbeddingProvider? = DefaultEmbeddingProvider.shared
    ) async {
        guard let story = campaign.story else { return }
        let analysis = story.analysisResult
        let rawText = story.rawText

        // Re-runnable: clear this campaign's targets (and their explanations).
        // Journalists live in the shared directory — never touched here.
        for target in campaign.mediaTargets {
            if let explanation = target.explanation { context.delete(explanation) }
            context.delete(target)
        }
        campaign.mediaTargets.removeAll()

        JournalistDirectory.ensureSeeded(context)
        await warmDirectory(context: context, embeddings: embeddings)
        let pool = JournalistDirectory.matchable(context)

        // The story's own vector — also off the main actor.
        let storyVector: [Double]? = await Task.detached(priority: .userInitiated) {
            embeddings?.vector(for: Embedding.storyText(analysis, rawText: rawText))
        }.value

        let candidates = service.match(analysis: analysis, storyVector: storyVector, against: pool)

        for candidate in candidates {
            context.insert(candidate.explanation)   // one per (campaign, journalist), rebuilt each run

            let target = MediaTarget(
                confidenceTier: candidate.confidenceTier,
                confidenceScore: candidate.confidenceScore,
                relevance: candidate.relevance,     // the breakdown behind the score/tier
                journalist: candidate.journalist,   // an existing directory record
                explanation: candidate.explanation
            )
            target.campaign = campaign
            campaign.mediaTargets.append(target)
        }
    }
}
