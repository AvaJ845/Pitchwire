import Foundation

protocol PitchDraftingService {
    /// `recipientName` / `matchReason` are passed as plain values — the caller
    /// reads them off the `@Model` on the main actor, never this method.
    func draft(story: StoryAnalysisResult, rawText: String,
               recipientName: String, matchReason: String) async throws -> PitchDraft
}

/// Pitch drafting runs the `.pitchDraft` task through the AI gateway (quality
/// tier) when a backend is configured, and falls back to a grounded template
/// offline. The template is never worse than "a bare number with no reason" —
/// every pitch says *why* this journalist.
struct DefaultPitchDraftingService: PitchDraftingService {
    var ai: AIClient = AIClient()

    func draft(story: StoryAnalysisResult, rawText: String,
               recipientName name: String, matchReason: String) async throws -> PitchDraft {
        let request = AIRequest(
            task: .pitchDraft,
            input: [
                "recipient": name,
                "story": String(rawText.prefix(2000)),
                "angle": story.angle,
                "audience": story.audience,
                "hooks": story.mediaHooks.joined(separator: ", "),
                "whyThisJournalist": matchReason
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

        Flagging this for you because \(matchReason)\(hookLine)

        Happy to send more detail or set up a quick call if useful.
        """

        let longBody = """
        Hi \(name),

        \(rawText.prefix(600))

        Why I thought of you: \(matchReason)

        The angle I think fits your beat: \(story.mediaHooks.joined(separator: "; "))

        Let me know if you'd like embargoed access, founder time, or additional data — happy to work around your schedule.

        Best,
        """

        return PitchDraft(subject: subject, shortBody: shortBody, longBody: longBody)
    }

    static func parse(_ raw: String) -> PitchDraft? {
        // Models sometimes wrap the labels ("**SUBJECT:**", "### SHORT") — strip
        // markdown emphasis/heading markers before splitting.
        let text = raw.replacingOccurrences(of: "*", with: "")
            .replacingOccurrences(of: "#", with: "")
            .replacingOccurrences(of: "`", with: "")

        func section(_ tag: String, until others: [String]) -> String? {
            guard let range = text.range(of: "\(tag):", options: .caseInsensitive) else { return nil }
            var rest = String(text[range.upperBound...])
            for other in others {
                if let cut = rest.range(of: "\(other):", options: .caseInsensitive) {
                    rest = String(rest[..<cut.lowerBound])
                }
            }
            return rest.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard
            let subject = section("SUBJECT", until: ["SHORT", "LONG"]),
            let short = section("SHORT", until: ["LONG", "SUBJECT"]),
            let long = section("LONG", until: ["SUBJECT", "SHORT"]),
            !subject.isEmpty, !short.isEmpty, !long.isEmpty
        else { return nil }
        return PitchDraft(subject: subject, shortBody: short, longBody: long)
    }
}
