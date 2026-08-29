import Foundation
import SwiftData

/// Progressive enhancement for "why this match": the relevance engine's grounded
/// one-liner shows instantly; when a backend is configured this rewrites it into
/// something a person would actually say — still grounded only in the facts we
/// pass (beat, real bylines, the story), never invented.
@MainActor
enum ExplanationEnricher {

    /// Rewrites the explanations for a campaign's top matches, in place.
    /// No-op when offline — the grounded reasons stay.
    static func enrich(campaign: Campaign, using ai: AIClient, context: ModelContext) async {
        guard ai.isConfigured, let story = campaign.story else { return }
        let analysis = story.analysisResult

        let pending = campaign.mediaTargets
            .filter { $0.explanation?.aiEnhanced == false }
            .sorted { $0.confidenceScore > $1.confidenceScore }
            .prefix(8)

        await withTaskGroup(of: (MatchExplanation, String)?.self) { group in
            for target in pending {
                guard let journalist = target.journalist, let explanation = target.explanation else { continue }
                let drivers = RelevanceEngine.score(analysis: analysis, journalist: journalist).drivers.map(\.name)
                group.addTask {
                    let text = await write(analysis: analysis, journalist: journalist,
                                           tier: target.confidenceTier, drivers: drivers, ai: ai)
                    return text.map { (explanation, $0) }
                }
            }
            for await result in group {
                guard let (explanation, text) = result else { continue }
                explanation.reasonText = text
                explanation.aiEnhanced = true
            }
        }
        try? context.save()
    }

    private static func write(
        analysis: StoryAnalysisResult,
        journalist: JournalistProfile,
        tier: ConfidenceTier,
        drivers: [String],
        ai: AIClient
    ) async -> String? {
        let request = AIRequest(
            task: .matchExplanation,
            tier: .fast,
            input: [
                "journalist": journalist.name,
                "outlet": journalist.outlet?.name ?? "",
                "beat": journalist.beatTopics.joined(separator: ", "),
                "recentBylines": journalist.recentBylineTitles.prefix(3).joined(separator: " | "),
                "story": analysis.summary,
                "storyAngle": analysis.angle,
                "matchStrength": tier.shortLabel,
                "topSignals": drivers.joined(separator: ", ")
            ],
            prompt: "In ONE sentence (max 30 words), say why this journalist is worth pitching this "
                + "story. Ground it only in the beat and bylines given. Refer to them by name or "
                + "'they' — never assume he/she. No greeting, no markdown."
        )
        guard let text = await ai.text(for: request) else { return nil }
        let cleaned = text
            .replacingOccurrences(of: "*", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        // Guard against a model that ignored the one-sentence instruction.
        return cleaned.count > 12 && cleaned.count < 400 ? cleaned : nil
    }
}
