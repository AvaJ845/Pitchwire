import Foundation

struct MatchCandidate {
    var journalist: JournalistProfile
    var confidenceTier: ConfidenceTier
    var confidenceScore: Double
    var explanation: MatchExplanation
    /// The weighted-signal breakdown behind the score, for the "how we scored this" detail.
    var relevance: RelevanceResult?
}

protocol MatchingService {
    /// `storyText` is the raw story (for on-device embedding); `embeddings` is
    /// nil when no model is available — the engine falls back to word overlap.
    func match(analysis: StoryAnalysisResult, storyText: String,
               against pool: [JournalistProfile],
               embeddings: EmbeddingProvider?) -> [MatchCandidate]
}

/// The relevance engine, applied over the pool. The model never decides who to
/// recommend — this reads structured beat / coverage / preference data and
/// produces a ranked, fully-explained list (see "Authority Split").
struct WeightedRelevanceService: MatchingService {
    /// Below this, a journalist isn't shown at all.
    var floor = 0.18

    func match(analysis: StoryAnalysisResult, storyText: String,
               against pool: [JournalistProfile],
               embeddings: EmbeddingProvider?) -> [MatchCandidate] {
        let storyVector = embeddings.flatMap { $0.vector(for: Embedding.storyText(analysis, rawText: storyText)) }

        return pool.compactMap { journalist in
            let similarity: Double? = {
                guard let storyVector, !journalist.embedding.isEmpty else { return nil }
                return Embedding.similarity(storyVector, journalist.embedding)
            }()

            let result = RelevanceEngine.score(analysis: analysis, journalist: journalist, similarity: similarity)
            guard result.total >= floor else { return nil }

            let explanation = MatchExplanation(
                reasonText: RelevanceEngine.prose(result, journalist: journalist),
                evidenceBylines: journalist.recentBylineTitles
            )
            return MatchCandidate(
                journalist: journalist,
                confidenceTier: result.tier,
                confidenceScore: result.total,
                explanation: explanation,
                relevance: result
            )
        }
        .sorted { $0.confidenceScore > $1.confidenceScore }
    }
}
