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

    /// The exact weighted-signal breakdown this score and tier came from — the
    /// on-device semantic-similarity term included. Persisted at match time so
    /// the "How we scored this" panel shows what actually drove the ranking,
    /// never a recompute that omits similarity. `nil` only for matches saved
    /// before this was stored.
    var relevance: RelevanceResult?

    var journalist: JournalistProfile?
    var explanation: MatchExplanation?
    var campaign: Campaign?

    init(confidenceTier: ConfidenceTier, confidenceScore: Double,
         relevance: RelevanceResult? = nil,
         journalist: JournalistProfile?, explanation: MatchExplanation?) {
        self.id = UUID()
        self.confidenceTier = confidenceTier
        self.confidenceScore = confidenceScore
        self.relevance = relevance
        self.status = .suggested
        self.createdAt = Date()
        self.journalist = journalist
        self.explanation = explanation
    }
}
