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
    /// `storyVector` is the story's on-device semantic embedding, or nil when no
    /// model is available (or it hasn't been computed) — the engine then falls
    /// back to word overlap. Computed off the main actor by the caller; this
    /// function is pure scoring math.
    func match(analysis: StoryAnalysisResult, storyVector: [Float]?,
               against pool: [JournalistProfile]) -> [MatchCandidate]
}

/// The relevance engine, applied over the pool. The model never decides who to
/// recommend — this reads structured beat / coverage / preference data and
/// produces a ranked, fully-explained list (see "Authority Split").
struct WeightedRelevanceService: MatchingService {
    /// Below this, a journalist isn't shown at all.
    var floor = 0.18

    func match(analysis: StoryAnalysisResult, storyVector: [Float]?,
               against pool: [JournalistProfile]) -> [MatchCandidate] {
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
