import Foundation
import SwiftData

enum StorySourceType: String, Codable, CaseIterable, Hashable {
    case pastedText
    case url
    case upload
}

enum AnalysisStatus: String, Codable, CaseIterable, Hashable {
    case pending
    case analyzed
    case failed
}

@Model
final class Story {
    var id: UUID
    var rawText: String
    var sourceType: StorySourceType
    var createdAt: Date
    var analysisStatus: AnalysisStatus

    // Structured analysis output only — the LLM interprets the story, it is never the
    // source of truth for who exists, their beat, or recency (see ARCHITECTURE.md,
    // and "Authority Split" in the AI Infrastructure Direction).
    var theme: String?
    var vertical: String?
    var region: String?
    var angle: String?
    var urgency: String?
    var summary: String?
    var audience: String?
    var subtopics: [String] = []
    var mediaHooks: [String] = []

    init(rawText: String, sourceType: StorySourceType = .pastedText) {
        self.id = UUID()
        self.rawText = rawText
        self.sourceType = sourceType
        self.createdAt = Date()
        self.analysisStatus = .pending
    }
}

extension Story {
    /// Single place that maps between `Story`'s stored fields and `StoryAnalysisResult`.
    /// Add a new analysis field here, not at every call site.
    func apply(_ analysis: StoryAnalysisResult) {
        theme = analysis.theme
        vertical = analysis.vertical
        region = analysis.region
        angle = analysis.angle
        urgency = analysis.urgency
        summary = analysis.summary
        audience = analysis.audience
        subtopics = analysis.subtopics
        mediaHooks = analysis.mediaHooks
        analysisStatus = .analyzed
    }

    var analysisResult: StoryAnalysisResult {
        StoryAnalysisResult(
            theme: theme ?? "",
            vertical: vertical ?? "",
            region: region ?? "",
            angle: angle ?? "",
            urgency: urgency ?? "",
            summary: summary ?? "",
            audience: audience ?? "",
            subtopics: subtopics,
            mediaHooks: mediaHooks
        )
    }
}
