import Foundation
import SwiftData

@Model
final class Campaign {
    var id: UUID
    var name: String
    var createdAt: Date

    @Relationship(deleteRule: .cascade)
    var story: Story?

    @Relationship(deleteRule: .cascade, inverse: \MediaTarget.campaign)
    var mediaTargets: [MediaTarget] = []

    @Relationship(deleteRule: .cascade, inverse: \PitchDraft.campaign)
    var pitchDrafts: [PitchDraft] = []

    @Relationship(deleteRule: .cascade, inverse: \FollowUpTask.campaign)
    var followUpTasks: [FollowUpTask] = []

    init(name: String, story: Story? = nil) {
        self.id = UUID()
        self.name = name
        self.createdAt = Date()
        self.story = story
    }
}
