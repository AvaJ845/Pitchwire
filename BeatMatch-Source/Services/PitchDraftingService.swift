import Foundation

protocol PitchDraftingService {
    func draft(story: StoryAnalysisResult, rawText: String, for candidate: MatchCandidate) async throws -> PitchDraft
}

/// Template-based implementation so Slice 0 runs with zero configuration.
/// Swap for the stronger-tier LLM implementation per the brief — never let the
/// cheapest model write user-visible text.
struct TemplatePitchDraftingService: PitchDraftingService {
    func draft(story: StoryAnalysisResult, rawText: String, for candidate: MatchCandidate) async throws -> PitchDraft {
        let name = candidate.journalist.name
        let subject = "\(story.theme) launch: \(story.angle) — thought of \(name)"

        let shortBody = """
        Hi \(name),

        \(story.summary)

        Flagging this because \(candidate.explanation.reasonText)

        Happy to send more detail or set up a quick call if useful.
        """

        let longBody = """
        Hi \(name),

        \(rawText.prefix(600))

        Why I thought of you: \(candidate.explanation.reasonText)

        Let me know if you'd like embargoed access, founder time, or additional data — happy to work around your schedule.

        Best,
        """

        return PitchDraft(subject: subject, shortBody: shortBody, longBody: longBody)
    }
}
