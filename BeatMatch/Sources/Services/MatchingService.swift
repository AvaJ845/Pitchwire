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
    func match(analysis: StoryAnalysisResult, against pool: [JournalistProfile]) -> [MatchCandidate]
}

/// The relevance engine, applied over the pool. The model never decides who to
/// recommend — this reads structured beat / coverage / preference data and
/// produces a ranked, fully-explained list (see "Authority Split").
struct WeightedRelevanceService: MatchingService {
    /// Below this, a journalist isn't shown at all.
    var floor = 0.18

    func match(analysis: StoryAnalysisResult, against pool: [JournalistProfile]) -> [MatchCandidate] {
        pool.compactMap { journalist in
            let result = RelevanceEngine.score(analysis: analysis, journalist: journalist)
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
