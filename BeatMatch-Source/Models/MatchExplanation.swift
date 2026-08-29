import Foundation
import SwiftData

@Model
final class MatchExplanation {
    var id: UUID
    var reasonText: String
    var evidenceBylines: [String]
    var createdAt: Date

    init(reasonText: String, evidenceBylines: [String] = []) {
        self.id = UUID()
        self.reasonText = reasonText
        self.evidenceBylines = evidenceBylines
        self.createdAt = Date()
    }
}
