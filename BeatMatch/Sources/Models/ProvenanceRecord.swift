import Foundation
import SwiftData

/// Where a piece of a journalist's profile came from, ordered most to least
/// authoritative. A profile can carry several — a claimed profile *and* a
/// public-signal record, say — rather than pretending there is one source.
enum ProvenanceSourceType: String, Codable, CaseIterable, Hashable {
    case claimedProfile      // the journalist claimed/edited this themselves
    case publisherPartner    // supplied by the outlet / a partner network
    case licensedDataset     // a licensed professional data provider
    case publicSignal        // derived from public bylines, author pages, RSS
    case sampleData          // development seed, not real

    var label: String {
        switch self {
        case .claimedProfile:  return "Claimed by the journalist"
        case .publisherPartner: return "Publisher / partner network"
        case .licensedDataset:  return "Licensed data provider"
        case .publicSignal:     return "Public editorial signals"
        case .sampleData:       return "Sample data (not verified)"
        }
    }

    /// Higher = more authoritative. Used to pick a profile's primary record.
    var authority: Int {
        switch self {
        case .claimedProfile:  return 4
        case .publisherPartner: return 3
        case .licensedDataset:  return 2
        case .publicSignal:     return 1
        case .sampleData:       return 0
        }
    }

    var systemImage: String {
        switch self {
        case .claimedProfile:  return "checkmark.seal.fill"
        case .publisherPartner: return "building.columns"
        case .licensedDataset:  return "doc.badge.gearshape"
        case .publicSignal:     return "antenna.radiowaves.left.and.right"
        case .sampleData:       return "testtube.2"
        }
    }
}

@Model
final class ProvenanceRecord {
    var id: UUID
    var sourceTypeRaw: String
    var detail: String
    var coverageBasis: String?
    var lastVerifiedAt: Date
    var pitchPreference: String?
    var issueReported: Bool

    var sourceType: ProvenanceSourceType {
        get { ProvenanceSourceType(rawValue: sourceTypeRaw) ?? .publicSignal }
        set { sourceTypeRaw = newValue.rawValue }
    }

    init(
        sourceType: ProvenanceSourceType,
        detail: String,
        coverageBasis: String? = nil,
        lastVerifiedAt: Date = Date(),
        pitchPreference: String? = nil,
        issueReported: Bool = false
    ) {
        self.id = UUID()
        self.sourceTypeRaw = sourceType.rawValue
        self.detail = detail
        self.coverageBasis = coverageBasis
        self.lastVerifiedAt = lastVerifiedAt
        self.pitchPreference = pitchPreference
        self.issueReported = issueReported
    }
}
