import Foundation
import SwiftData

enum ConfidenceTier: String, Codable, CaseIterable, Hashable {
    case excellent
    case strong
    case possible

    var displayName: String {
        switch self {
        case .excellent: return "Excellent match"
        case .strong: return "Strong match"
        case .possible: return "Possible match"
        }
    }
}

enum MediaTargetStatus: String, Codable, CaseIterable, Hashable {
    case suggested
    case shortlisted
    case hidden
}

@Model
final class MediaTarget {
    var id: UUID
    var confidenceTier: ConfidenceTier
    var confidenceScore: Double
    var status: MediaTargetStatus
    var createdAt: Date

    var journalist: JournalistProfile?
    var explanation: MatchExplanation?
    var campaign: Campaign?

    init(confidenceTier: ConfidenceTier, confidenceScore: Double, journalist: JournalistProfile?, explanation: MatchExplanation?) {
        self.id = UUID()
        self.confidenceTier = confidenceTier
        self.confidenceScore = confidenceScore
        self.status = .suggested
        self.createdAt = Date()
        self.journalist = journalist
        self.explanation = explanation
    }
}
