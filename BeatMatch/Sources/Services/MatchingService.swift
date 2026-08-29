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

/// Deterministic topic-overlap scoring. The model never decides who to recommend —
/// this layer does, from structured beat + coverage data (see "Authority Split").
/// The model's only job downstream is turning this reason into readable prose.
struct KeywordMatchingService: MatchingService {
    func match(analysis: StoryAnalysisResult, against pool: [JournalistProfile]) -> [MatchCandidate] {
        let storyKeywords = Self.keywords(from:
            [analysis.vertical, analysis.theme, analysis.angle, analysis.audience] + analysis.subtopics
        )

        let candidates: [MatchCandidate] = pool.compactMap { journalist in
            let beatKeywords = Self.keywords(from: journalist.beatTopics)
            let overlap = beatKeywords.intersection(storyKeywords)
            guard !overlap.isEmpty else { return nil }

            // Base fit from beat overlap, plus a nudge for evidence confidence so a
            // fresh, claimed profile outranks a stale licensed one at equal topic fit.
            let topicFit = min(1.0, Double(overlap.count) / Double(max(beatKeywords.count, 1)) + 0.2)
            let confidenceBonus: Double
            switch journalist.evidenceConfidence {
            case .high: confidenceBonus = 0.12
            case .moderate: confidenceBonus = 0.04
            case .exploratory: confidenceBonus = 0.0
            }
            let score = min(1.0, topicFit + confidenceBonus)
            let tier: ConfidenceTier = score >= 0.75 ? .excellent : (score >= 0.5 ? .strong : .possible)

            let matched = overlap.sorted().joined(separator: ", ")
            var reason = "Covers \(journalist.beatTopics.prefix(3).joined(separator: ", ")) — overlaps on \(matched)."
            if let basis = journalist.primaryProvenance?.coverageBasis {
                reason += " \(basis)."
            }
            if let pref = journalist.pitchPreference {
                reason += " Prefers: \(pref)."
            }
            let explanation = MatchExplanation(reasonText: reason, evidenceBylines: journalist.recentBylineTitles)

            return MatchCandidate(journalist: journalist, confidenceTier: tier, confidenceScore: score, explanation: explanation)
        }

        return candidates.sorted { $0.confidenceScore > $1.confidenceScore }
    }

    private static func keywords(from strings: [String]) -> Set<String> {
        let stop: Set<String> = ["the", "and", "for", "with", "your", "a", "of", "to", "in", "on"]
        return Set(
            strings
                .flatMap { $0.lowercased().split { !$0.isLetter }.map(String.init) }
                .filter { $0.count > 1 && !stop.contains($0) }
        )
    }
}
