import Foundation
import SwiftData

enum PitchDraftStatus: String, Codable, CaseIterable, Hashable {
    case draft
    case markedSent
}

@Model
final class PitchDraft {
    var id: UUID
    var subject: String
    var shortBody: String
    var longBody: String
    var status: PitchDraftStatus
    var createdAt: Date

    var mediaTarget: MediaTarget?
    var campaign: Campaign?

    init(subject: String, shortBody: String, longBody: String, mediaTarget: MediaTarget? = nil) {
        self.id = UUID()
        self.subject = subject
        self.shortBody = shortBody
        self.longBody = longBody
        self.status = .draft
        self.createdAt = Date()
        self.mediaTarget = mediaTarget
    }
}
