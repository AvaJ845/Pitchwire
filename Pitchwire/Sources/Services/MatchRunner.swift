import Foundation
import SwiftData

/// Turns a campaign's analyzed story into persisted `MediaTarget`s.
/// Shared by the first run and any re-run after the user edits the story tags.
@MainActor
enum MatchRunner {

    /// A single in-flight warm, so the launch pre-warm and a fast "Find
    /// journalists" don't both embed the same 20 profiles.
    private static var warmInFlight: Task<Void, Never>?

    /// Compute and cache the on-device semantic vector for every directory
    /// profile that's missing one. **All model work — load, tokenize, infer —
    /// runs off the main actor**; only the SwiftData reads and writes touch it.
    /// Idempotent and coalesced: a no-op once every profile is warm, and a
    /// second concurrent call just awaits the first. Called at launch
    /// (background priority) and again just before a match run.
    static func warmDirectory(
        context: ModelContext,
        embeddings: EmbeddingProvider? = nil,
        priority: TaskPriority = .userInitiated
    ) async {
        if let existing = warmInFlight { await existing.value; return }

        let task = Task { await performWarm(context: context, embeddings: embeddings, priority: priority) }
        warmInFlight = task
        await task.value
        warmInFlight = nil
    }

    private static func performWarm(
        context: ModelContext,
        embeddings: EmbeddingProvider?,
        priority: TaskPriority
    ) async {
        let pool = JournalistDirectory.matchable(context)
        let pending: [(id: PersistentIdentifier, text: String)] = pool
            .filter { $0.embedding.count != MiniLMEmbeddingProvider.dimension }
            .map { ($0.persistentModelID, $0.embeddingText) }
        guard !pending.isEmpty else { return }

        let warmed: [PersistentIdentifier: [Float]] = await Task.detached(priority: priority) {
            // Resolve the provider HERE — `DefaultEmbeddingProvider.shared` lazily
            // loads a 16 MB model + a 30k-line vocab, and that must not happen on
            // the main actor.
            guard let provider = embeddings ?? DefaultEmbeddingProvider.shared else { return [:] }
            var out: [PersistentIdentifier: [Float]] = [:]
            for item in pending {
                if Task.isCancelled { break }
                if let v = provider.vector(for: item.text),
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
    }

    static func populateTargets(
        for campaign: Campaign,
        context: ModelContext,
        service: MatchingService = WeightedRelevanceService(),
        embeddings: EmbeddingProvider? = nil
    ) async {
        guard let story = campaign.story else { return }
        let analysis = story.analysisResult

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

        // The story's own vector — off the main actor, provider resolved there.
        let storyVector: [Float]? = await Task.detached(priority: .userInitiated) {
            guard let provider = embeddings ?? DefaultEmbeddingProvider.shared else { return nil }
            return provider.vector(for: Embedding.storyText(analysis))
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
