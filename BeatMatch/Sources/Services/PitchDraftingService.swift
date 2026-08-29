import Foundation

protocol PitchDraftingService {
    func draft(story: StoryAnalysisResult, rawText: String, for candidate: MatchCandidate) async throws -> PitchDraft
}

/// Pitch drafting runs the `.pitchDraft` task through the AI gateway (quality
/// tier) when a backend is configured, and falls back to a grounded template
/// offline. The template is never worse than "a bare number with no reason" —
/// every pitch says *why* this journalist.
struct DefaultPitchDraftingService: PitchDraftingService {
    var ai: AIClient = AIClient()

    func draft(story: StoryAnalysisResult, rawText: String, for candidate: MatchCandidate) async throws -> PitchDraft {
        let name = candidate.journalist.name

        let request = AIRequest(
            task: .pitchDraft,
            input: [
                "recipient": name,
                "story": String(rawText.prefix(2000)),
                "angle": story.angle,
                "audience": story.audience,
                "hooks": story.mediaHooks.joined(separator: ", "),
                "whyThisJournalist": candidate.explanation.reasonText
            ],
            prompt: "Draft a media pitch. Return: SUBJECT: <line>\\nSHORT: <text>\\nLONG: <text>"
        )
        if let generated = await ai.text(for: request), let parsed = Self.parse(generated) {
            return parsed
        }

        // Deterministic fallback — grounded in the story + the match reason.
        let subject = "\(story.theme): \(story.angle.capitalized) — thought of you, \(name)"
        let hookLine = story.mediaHooks.first.map { " (\($0.lowercased()))" } ?? ""

        let shortBody = """
        Hi \(name),

        \(story.summary)

        Flagging this for you because \(candidate.explanation.reasonText)\(hookLine)

        Happy to send more detail or set up a quick call if useful.
        """

        let longBody = """
        Hi \(name),

        \(rawText.prefix(600))

        Why I thought of you: \(candidate.explanation.reasonText)

        The angle I think fits your beat: \(story.mediaHooks.joined(separator: "; "))

        Let me know if you'd like embargoed access, founder time, or additional data — happy to work around your schedule.

        Best,
        """

        return PitchDraft(subject: subject, shortBody: shortBody, longBody: longBody)
    }

    private static func parse(_ text: String) -> PitchDraft? {
        func section(_ tag: String) -> String? {
            guard let range = text.range(of: "\(tag):", options: .caseInsensitive) else { return nil }
            let rest = text[range.upperBound...]
            let end = rest.range(of: "\n[A-Z]+:", options: .regularExpression)?.lowerBound ?? rest.endIndex
            return rest[..<end].trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard let subject = section("SUBJECT"), let short = section("SHORT"), let long = section("LONG") else { return nil }
        return PitchDraft(subject: subject, shortBody: short, longBody: long)
    }
}
