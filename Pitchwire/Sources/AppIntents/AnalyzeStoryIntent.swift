import AppIntents

/// "Analyze a story in Pitchwire" — from Shortcuts, Siri, or Spotlight.
/// Hands the text to the app through the same one-slot inbox the Share
/// Extension uses; the app picks it up and pre-fills Home.
struct AnalyzeStoryIntent: AppIntent {
    static var title: LocalizedStringResource = "Analyze a story"
    static var description = IntentDescription(
        "Send a launch story or announcement to Pitchwire to find relevant editorial professionals.")
    static var openAppWhenRun = true

    @Parameter(title: "Story", inputOptions: String.IntentInputOptions(multiline: true))
    var story: String

    @MainActor
    func perform() async throws -> some IntentResult {
        SharedInbox.stash(story)
        return .result()
    }
}

struct PitchwireShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AnalyzeStoryIntent(),
            phrases: [
                "Analyze a story in \(.applicationName)",
                "Find journalists with \(.applicationName)",
            ],
            shortTitle: "Analyze a story",
            systemImageName: "sparkles.rectangle.stack"
        )
    }
}
