import Foundation
import SwiftData

/// How a piece of a profile's editorial context was obtained. Explicit, spec-defined
/// classifications — the string `rawValue`s are the contract with `editorial_seed.json`
/// and any future data-provider import.
enum ProvenanceType: String, Codable, CaseIterable, Hashable {
    case publicEditorialSignal = "PUBLIC_EDITORIAL_SIGNAL"   // public bylines, author pages, RSS
    case publisherProvided     = "PUBLISHER_PROVIDED"        // first-party from the outlet / a partner
    case claimedProfile        = "CLAIMED_PROFILE"           // the professional claimed / edited it
    case licensedSource        = "LICENSED_SOURCE"           // a licensed dataset, rights documented
    case userProvided          = "USER_PROVIDED"             // the app's user supplied it
    case fictionalSample       = "FICTIONAL_SAMPLE"          // dev seed — never a real person

    var label: String {
        switch self {
        case .publicEditorialSignal: return "Public editorial signals"
        case .publisherProvided:     return "Publisher / partner"
        case .claimedProfile:        return "Claimed by the professional"
        case .licensedSource:        return "Licensed data source"
        case .userProvided:          return "Provided by you"
        case .fictionalSample:       return "Fictional demo profile"
        }
    }

    /// Higher = more authoritative. Picks a profile's primary record.
    var authority: Int {
        switch self {
        case .claimedProfile:        return 5
        case .publisherProvided:     return 4
        case .licensedSource:        return 3
        case .publicEditorialSignal: return 2
        case .userProvided:          return 1
        case .fictionalSample:       return 0
        }
    }

    var systemImage: String {
        switch self {
        case .publicEditorialSignal: return "antenna.radiowaves.left.and.right"
        case .publisherProvided:     return "building.columns"
        case .claimedProfile:        return "checkmark.seal.fill"
        case .licensedSource:        return "doc.badge.gearshape"
        case .userProvided:          return "person.crop.circle"
        case .fictionalSample:       return "flask"
        }
    }
}

/// One sourced claim about an editorial professional's relevance — where it came
/// from, the articles that back it, and whether a **human** has verified it.
///
/// Nothing here is "verified" until `verificationDate` is set by a person in the
/// Research Lab. AI can discover and summarise; it can never verify.
@Model
final class EditorialEvidenceRecord {
    var id: UUID
    var provenanceRaw: String
    /// Grounded "why this source supports relevance", written from the articles.
    /// Never invented — if a claim can't be traced to `articles` / `sourceURL`,
    /// it doesn't belong here.
    var evidenceSummary: String
    /// The traceable source a person can open — author page, publisher staff page.
    var sourceURL: String?
    /// Set only when a human reviewed the underlying sources. `nil` = candidate.
    var verificationDate: Date?
    /// Who verified it (researcher initials / name). `nil` until verified.
    var verifiedBy: String?
    var confidenceRaw: String
    /// A pitch preference **only if the professional published it themselves**,
    /// quoted verbatim, with `sourceURL` pointing at where they said it.
    var pitchPreference: String?
    var issueReported: Bool

    var profile: JournalistProfile?

    @Relationship(deleteRule: .cascade, inverse: \CoverageEvidence.record)
    var articles: [CoverageEvidence] = []

    var provenance: ProvenanceType {
        get { ProvenanceType(rawValue: provenanceRaw) ?? .publicEditorialSignal }
        set { provenanceRaw = newValue.rawValue }
    }

    var confidence: EvidenceConfidence {
        get { EvidenceConfidence(rawValue: confidenceRaw) ?? .exploratory }
        set { confidenceRaw = newValue.rawValue }
    }

    var isVerified: Bool { verificationDate != nil }

    init(
        provenance: ProvenanceType,
        evidenceSummary: String,
        sourceURL: String? = nil,
        verificationDate: Date? = nil,
        verifiedBy: String? = nil,
        confidence: EvidenceConfidence = .exploratory,
        pitchPreference: String? = nil,
        issueReported: Bool = false
    ) {
        self.id = UUID()
        self.provenanceRaw = provenance.rawValue
        self.evidenceSummary = evidenceSummary
        self.sourceURL = sourceURL
        self.verificationDate = verificationDate
        self.verifiedBy = verifiedBy
        self.confidenceRaw = confidence.rawValue
        self.pitchPreference = pitchPreference
        self.issueReported = issueReported
    }
}
