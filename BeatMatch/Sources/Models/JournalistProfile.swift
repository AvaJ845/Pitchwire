import Foundation
import SwiftData

/// How current / trustworthy a profile's evidence is right now. Shown next to
/// matches so the recommendation reads as honest, not authoritative-by-fiat.
enum EvidenceConfidence: String, Codable {
    case high
    case moderate
    case exploratory

    var label: String {
        switch self {
        case .high:        return "High confidence"
        case .moderate:    return "Moderate confidence"
        case .exploratory: return "Exploratory"
        }
    }
}

@Model
final class JournalistProfile {
    var id: UUID
    var name: String
    var beatTopics: [String]
    var recentBylineTitles: [String]
    var outlet: Outlet?

    @Relationship(deleteRule: .cascade)
    var provenanceRecords: [ProvenanceRecord] = []

    init(name: String, beatTopics: [String] = [], recentBylineTitles: [String] = [], outlet: Outlet? = nil) {
        self.id = UUID()
        self.name = name
        self.beatTopics = beatTopics
        self.recentBylineTitles = recentBylineTitles
        self.outlet = outlet
    }
}

extension JournalistProfile {
    /// The most authoritative record — what the profile "is" first.
    var primaryProvenance: ProvenanceRecord? {
        provenanceRecords.max { $0.sourceType.authority < $1.sourceType.authority }
    }

    /// Records ordered most to least authoritative, for the detail view.
    var orderedProvenance: [ProvenanceRecord] {
        provenanceRecords.sorted { $0.sourceType.authority > $1.sourceType.authority }
    }

    var pitchPreference: String? {
        orderedProvenance.compactMap(\.pitchPreference).first
    }

    var hasReportedIssue: Bool {
        provenanceRecords.contains(where: \.issueReported)
    }

    /// True while this profile is a fictional stand-in (every source is sample
    /// data). Real ingestion replaces these records with real ones and this
    /// flips to false — the sample banners then disappear on their own.
    var isSampleData: Bool {
        !provenanceRecords.isEmpty && provenanceRecords.allSatisfy { $0.sourceType == .sampleData }
    }

    /// Confidence = how authoritative the best source is + how recently it was verified.
    var evidenceConfidence: EvidenceConfidence {
        guard let primary = primaryProvenance else { return .exploratory }
        let days = Calendar.current.dateComponents([.day], from: primary.lastVerifiedAt, to: Date()).day ?? 9_999
        switch primary.sourceType {
        case .claimedProfile, .publisherPartner:
            return days <= 120 ? .high : .moderate
        case .licensedDataset, .publicSignal:
            return days <= 120 ? .moderate : .exploratory
        case .sampleData:
            return .exploratory
        }
    }
}
