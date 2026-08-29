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

    // Structured analysis output only — the LLM is never the source of truth
    // for who exists, their beat, or recency (see ARCHITECTURE.md, Fellow 3).
    var theme: String?
    var vertical: String?
    var region: String?
    var angle: String?
    var urgency: String?
    var summary: String?

    init(rawText: String, sourceType: StorySourceType = .pastedText) {
        self.id = UUID()
        self.rawText = rawText
        self.sourceType = sourceType
        self.createdAt = Date()
        self.analysisStatus = .pending
    }
}
