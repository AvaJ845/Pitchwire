import Foundation
import SwiftData

@Model
final class MatchExplanation {
    var id: UUID
    var reasonText: String
    var evidenceBylines: [String]
    var createdAt: Date
    /// The deterministic reason from the relevance engine, shown instantly. The
    /// model-written version replaces `reasonText` once it arrives (progressive
    /// enhancement); this keeps the grounded original for reference / fallback.
    var groundedReason: String = ""
    var aiEnhanced: Bool = false

    init(reasonText: String, evidenceBylines: [String] = []) {
        self.id = UUID()
        self.reasonText = reasonText
        self.groundedReason = reasonText
        self.evidenceBylines = evidenceBylines
        self.createdAt = Date()
    }
}
