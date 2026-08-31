import Foundation
import SwiftData

@Model
final class FollowUpTask {
    var id: UUID
    var title: String
    var dueDate: Date?
    var isDone: Bool
    var campaign: Campaign?

    init(title: String, dueDate: Date? = nil, campaign: Campaign? = nil) {
        self.id = UUID()
        self.title = title
        self.dueDate = dueDate
        self.isDone = false
        self.campaign = campaign
    }
}
