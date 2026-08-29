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
            let topicFit = min(1.0, Double(overlap.count) / Double(max(beatKeywords.count, 1)) + 0.1)
            let confidenceBonus: Double
            switch journalist.evidenceConfidence {
            case .high: confidenceBonus = 0.14
            case .moderate: confidenceBonus = 0.05
            case .exploratory: confidenceBonus = 0.0
            }
            let score = min(1.0, topicFit + confidenceBonus)
            let tier: ConfidenceTier = score >= 0.8 ? .excellent : (score >= 0.55 ? .strong : .possible)

            let reason = Self.reason(journalist: journalist, tier: tier)
            let explanation = MatchExplanation(reasonText: reason, evidenceBylines: journalist.recentBylineTitles)

            return MatchCandidate(journalist: journalist, confidenceTier: tier, confidenceScore: score, explanation: explanation)
        }

        return candidates.sorted { $0.confidenceScore > $1.confidenceScore }
    }

    /// A readable one-liner grounded in the journalist's real beat — the shape a
    /// quality-tier model would produce, done deterministically for the offline path.
    /// Kept free of the story's own vocabulary so it never repeats itself.
    private static func reason(journalist: JournalistProfile, tier: ConfidenceTier) -> String {
        let beats = journalist.beatTopics.prefix(2).map(displayBeat)
        let phrase: String
        switch beats.count {
        case 0:  phrase = "this area"
        case 1:  phrase = beats[0]
        default: phrase = "\(beats[0]) and \(beats[1])"
        }
        switch tier {
        case .excellent:
            return "Covers \(phrase) — a direct hit for this story."
        case .strong:
            return "Covers \(phrase), which this story runs through."
        case .possible:
            return "Some overlap with \(phrase) — a lighter fit worth a look."
        }
    }

    private static func displayBeat(_ raw: String) -> String {
        switch raw {
        case "ai": return "AI"
        case "apis", "api": return "APIs"
        case "sdk": return "SDKs"
        case "ml": return "machine learning"
        default: return raw
        }
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
