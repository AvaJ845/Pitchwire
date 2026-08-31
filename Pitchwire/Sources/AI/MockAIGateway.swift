#if DEBUG
import Foundation

/// Canned, instant AI responses for UI tests. Swapped in by the
/// `-uitest-mock-ai` launch argument (see `PitchwireApp`) so the core-loop
/// tests exercise the real progressive-enhancement paths — analysis, in-place
/// explanation rewrite, pitch polish — without depending on the live Worker or
/// its free-tier latency.
///
/// DEBUG-only. The flag is always false in a release build, and this file is
/// compiled out entirely.
struct MockAIGateway: AIGateway {
    func run(_ request: AIRequest) async throws -> AIResponse {
        let text: String
        switch request.task {
        case .storyAnalysis:
            text = Self.storyAnalysisJSON
        case .matchExplanation:
            text = "They cover this beat closely and have returned to it repeatedly in recent months, "
                + "which lines up with the core of this story."
        case .pitchDraft, .pitchRewrite:
            text = """
            SUBJECT: A quick note ahead of our launch
            SHORT: Hi — flagging this because it lines up closely with what you cover. \
            Happy to share more detail or set up a short call.
            LONG: Hi,

            Sharing this ahead of launch because it fits your beat. I can offer embargoed \
            detail, founder time, or supporting data on request.

            Best,
            """
        case .subjectLine:
            text = "A quick note ahead of our launch"
        case .followUp:
            text = "Following up on the note from last week in case it's useful for anything on your plate."
        case .verificationBrief:
            text = """
            CHECKS:
            - Confirm the byline on the outlet's own site
            - Confirm the beat matches their recent articles
            SEARCHES:
            - reporter name site:outlet.com
            """
        }
        return AIResponse(text: text, model: "mock", cached: false,
                          usage: AIUsage(inputTokens: 0, outputTokens: 0))
    }

    /// Matches `StoryAnalysisResult` exactly — every field present, decodable.
    private static let storyAnalysisJSON = """
    {"theme":"AI developer tools","vertical":"ai","region":"US","angle":"product launch",\
    "urgency":"time-sensitive",\
    "summary":"A launch of an AI developer-tools SDK that helps small teams ship machine-learning \
    features quickly, with the founder available for interviews.",\
    "audience":"Developers",\
    "subtopics":["ai","developer tools","sdk","machine learning"],\
    "mediaHooks":["Founder available for interview","What the product does, in one line"]}
    """
}
#endif
