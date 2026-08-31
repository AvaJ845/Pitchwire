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
    /// The grounded template shows instantly; this flips true once the model has
    /// rewritten it in place.
    var aiEnhanced: Bool = false

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

    convenience init(content: PitchContent, mediaTarget: MediaTarget? = nil) {
        self.init(subject: content.subject, shortBody: content.shortBody,
                  longBody: content.longBody, mediaTarget: mediaTarget)
    }

    func apply(_ content: PitchContent) {
        subject = content.subject
        shortBody = content.shortBody
        longBody = content.longBody
    }
}
