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

        // Sequential on purpose: the backend rate-limits per IP, and each result
        // is written back on the main actor so the card upgrades in place as we go.
        // `.task` cancellation (navigating away) simply stops the loop — the next
        // visit resumes from the `aiEnhanced == false` filter.
        for target in pending {
            if Task.isCancelled { return }
            guard let journalist = target.journalist, let explanation = target.explanation else { continue }

            // Read every SwiftData field HERE, on the main actor, into a plain
            // request value. Nothing @Model crosses the `await`.
            let drivers = RelevanceEngine.score(analysis: analysis, journalist: journalist).drivers.map(\.name)
            let request = makeRequest(analysis: analysis, journalist: journalist,
                                      tier: target.confidenceTier, drivers: drivers)

            guard let text = await rewrite(request, using: ai) else { continue }
            explanation.reasonText = text
            explanation.aiEnhanced = true
            try? context.save()
        }
    }

    /// Pure — runs on the caller's actor (main). Pulls the journalist's facts into
    /// a plain `AIRequest`.
    private static func makeRequest(
        analysis: StoryAnalysisResult,
        journalist: JournalistProfile,
        tier: ConfidenceTier,
        drivers: [String]
    ) -> AIRequest {
        AIRequest(
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
    }

    /// The only part that suspends. Takes a plain value; touches nothing @Model.
    private static func rewrite(_ request: AIRequest, using ai: AIClient) async -> String? {
        guard let text = await ai.text(for: request) else { return nil }
        let cleaned = text
            .replacingOccurrences(of: "*", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        // Guard against a model that ignored the one-sentence instruction.
        return cleaned.count > 12 && cleaned.count < 400 ? cleaned : nil
    }
}
