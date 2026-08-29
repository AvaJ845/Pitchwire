import Foundation

struct MatchCandidate {
    var journalist: JournalistProfile
    var confidenceTier: ConfidenceTier
    var confidenceScore: Double
    var explanation: MatchExplanation
}

protocol MatchingService {
    func match(analysis: StoryAnalysisResult, against pool: [JournalistProfile]) -> [MatchCandidate]
}

/// Deterministic topic-overlap scoring. The LLM is never the source of truth for
/// who exists, their beat, or recency — that's this data layer's job (see brief).
struct KeywordMatchingService: MatchingService {
    func match(analysis: StoryAnalysisResult, against pool: [JournalistProfile]) -> [MatchCandidate] {
        let storyKeywords = Self.keywords(from: [analysis.vertical, analysis.theme, analysis.angle])

        let candidates: [MatchCandidate] = pool.compactMap { journalist in
            let beatKeywords = Self.keywords(from: journalist.beatTopics)
            let overlap = beatKeywords.intersection(storyKeywords)
            guard !overlap.isEmpty else { return nil }

            let score = min(1.0, Double(overlap.count) / Double(max(beatKeywords.count, 1)) + 0.25)
            let tier: ConfidenceTier = score >= 0.75 ? .excellent : (score >= 0.5 ? .strong : .possible)
            let reason = "Covers \(journalist.beatTopics.joined(separator: ", "))"
                + " — overlaps with this story's \(analysis.vertical) / \(analysis.angle) angle."
            let explanation = MatchExplanation(reasonText: reason, evidenceBylines: journalist.recentBylineTitles)

            return MatchCandidate(journalist: journalist, confidenceTier: tier, confidenceScore: score, explanation: explanation)
        }

        return candidates.sorted { $0.confidenceScore > $1.confidenceScore }
    }

    private static func keywords(from strings: [String]) -> Set<String> {
        Set(strings.flatMap { $0.lowercased().split(separator: " ").map(String.init) })
    }
}
