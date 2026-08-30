import Foundation
import SwiftData

/// Progressive enhancement for "why this match": the relevance engine's grounded
/// one-liner shows instantly; when a backend is configured this rewrites it into
/// something a person would actually say — still grounded only in the facts we
/// pass (beat, real bylines, the story), never invented.
///
/// Runs as **background** work — every call yields the AI pipeline to anything a
/// person is waiting on (a pitch draft). The match list warms only the top few;
/// any card the user actually opens is enriched on open (`enrichOne`).
@MainActor
enum ExplanationEnricher {

    /// How many of a campaign's top matches to warm proactively on the list.
    static let warmCount = 3

    static func enrich(campaign: Campaign, using ai: AIClient, context: ModelContext) async {
        guard ai.isConfigured, let story = campaign.story else { return }
        let analysis = story.analysisResult

        let pending = campaign.mediaTargets
            .filter { $0.explanation?.aiEnhanced == false }
            .sorted { $0.confidenceScore > $1.confidenceScore }
            .prefix(warmCount)

        for target in pending {
            if Task.isCancelled { return }
            await enrichOne(target: target, analysis: analysis, using: ai, context: context)
        }
    }

    /// Enrich one match's explanation in place. Safe to call repeatedly — a no-op
    /// once `aiEnhanced`. Called by `JournalistDetailView` on open.
    @discardableResult
    static func enrichOne(
        target: MediaTarget,
        analysis: StoryAnalysisResult,
        using ai: AIClient,
        context: ModelContext
    ) async -> Bool {
        guard ai.isConfigured,
              target.explanation?.aiEnhanced == false,
              let journalist = target.journalist,
              let explanation = target.explanation
        else { return false }

        // Read every SwiftData field HERE, on the main actor, into a plain
        // request value. Nothing @Model crosses the `await`.
        let drivers = RelevanceEngine.score(analysis: analysis, journalist: journalist).drivers.map(\.name)
        let request = makeRequest(analysis: analysis, journalist: journalist,
                                  tier: target.confidenceTier, drivers: drivers)

        guard let text = await rewrite(request, using: ai) else { return false }
        explanation.reasonText = text
        explanation.aiEnhanced = true
        try? context.save()
        return true
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
            prompt: "In ONE sentence (max 28 words), say why this journalist is worth pitching this "
                + "story. Name the specific beat/coverage overlap and the specific story element. "
                + "Ground it only in the beat and bylines given. Refer to them by name or 'they' — "
                + "never assume he/she. No greeting, no markdown, no 'a solid fit' filler.",
            origin: .background
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
