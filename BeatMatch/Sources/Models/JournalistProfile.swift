import Foundation
import SwiftData

/// How current / trustworthy a profile's evidence is right now. Shown next to
/// matches so the recommendation reads as honest, not authoritative-by-fiat.
enum EvidenceConfidence: String, Codable, CaseIterable, Comparable {
    case exploratory
    case moderate
    case high

    var label: String {
        switch self {
        case .high:        return "High confidence"
        case .moderate:    return "Moderate confidence"
        case .exploratory: return "Exploratory"
        }
    }

    private var rank: Int {
        switch self {
        case .exploratory: return 0
        case .moderate:    return 1
        case .high:        return 2
        }
    }

    static func < (lhs: EvidenceConfidence, rhs: EvidenceConfidence) -> Bool {
        lhs.rank < rhs.rank
    }
}

/// An editorial professional (reporter, editor, newsletter author) and the public
/// editorial context that makes them relevant to a story. **No contact data** —
/// not modelled, not stored, not inferred. Kept as an internal codename; the
/// product language is "editorial professional", never "journalist contact".
@Model
final class JournalistProfile {
    var id: UUID
    var name: String
    var role: String?                   // "Senior Reporter, AI" — as the outlet lists it
    var beatTopics: [String]
    var outlet: Outlet?

    // Signals for the relevance engine. All from public editorial context —
    // who they write for, where, and which story angles they actually cover.
    var audiences: [String] = []        // Developers / Founders / Consumers / Businesses
    var regions: [String] = []          // US / EU / Global
    var coveredAngles: [String] = []    // product launch / funding / acquisition / hire / partnership
    var doNotPitch: [String] = []       // angles or topics they've publicly said not to pitch

    /// A researcher rejected this candidate in the Research Lab — excluded from
    /// all matching, kept only so it isn't re-imported from the seed.
    var isRejected: Bool = false
    /// The vertical this record was researched under (from the seed file).
    var vertical: String?
    /// Cached on-device semantic vector of `embeddingText`, packed as raw
    /// little-endian Float32 (384 × 4 = 1536 bytes) — SwiftData won't store a
    /// `[Float]` directly, and this is tighter than `[Double]` anyway. It's a
    /// device-local cache, re-warmed whenever `embedding.count` doesn't match
    /// `MiniLMEmbeddingProvider.dimension`, so portability doesn't matter.
    private var embeddingBlob: Data = Data()

    var embedding: [Float] {
        get {
            guard !embeddingBlob.isEmpty else { return [] }
            return embeddingBlob.withUnsafeBytes { Array($0.bindMemory(to: Float.self)) }
        }
        set { embeddingBlob = newValue.withUnsafeBytes { Data($0) } }
    }

    @Relationship(deleteRule: .cascade, inverse: \EditorialEvidenceRecord.profile)
    var evidenceRecords: [EditorialEvidenceRecord] = []

    init(
        name: String,
        role: String? = nil,
        beatTopics: [String] = [],
        outlet: Outlet? = nil,
        audiences: [String] = [],
        regions: [String] = [],
        coveredAngles: [String] = [],
        doNotPitch: [String] = [],
        vertical: String? = nil
    ) {
        self.id = UUID()
        self.name = name
        self.role = role
        self.beatTopics = beatTopics
        self.outlet = outlet
        self.audiences = audiences
        self.regions = regions
        self.coveredAngles = coveredAngles
        self.doNotPitch = doNotPitch
        self.vertical = vertical
    }
}

extension JournalistProfile {
    /// Every sourced article across all evidence records, most recent first.
    /// Articles with no known date sort last.
    var allCoverage: [CoverageEvidence] {
        evidenceRecords.flatMap(\.articles).sorted {
            ($0.publishedAt ?? .distantPast) > ($1.publishedAt ?? .distantPast)
        }
    }

    /// Titles only — kept for the relevance engine's text matching and the
    /// pitch-draft context. Derived, never stored.
    var recentBylineTitles: [String] { allCoverage.map(\.title) }

    /// The most authoritative record — what the profile "is" first.
    var primaryEvidence: EditorialEvidenceRecord? {
        evidenceRecords.max { $0.provenance.authority < $1.provenance.authority }
    }

    /// Records ordered most to least authoritative, for the detail view.
    var orderedEvidence: [EditorialEvidenceRecord] {
        evidenceRecords.sorted { $0.provenance.authority > $1.provenance.authority }
    }

    var pitchPreference: String? {
        orderedEvidence.compactMap(\.pitchPreference).first
    }

    var hasReportedIssue: Bool {
        evidenceRecords.contains(where: \.issueReported)
    }

    /// A fictional stand-in — every record is `.fictionalSample`. Real ingestion
    /// replaces these and the demo banners disappear on their own.
    var isFictional: Bool {
        !evidenceRecords.isEmpty && evidenceRecords.allSatisfy { $0.provenance == .fictionalSample }
    }

    /// A real professional whose evidence no human has verified yet. Shown as a
    /// "candidate" everywhere — never as "verified".
    var isUnverifiedCandidate: Bool {
        !isFictional && !evidenceRecords.isEmpty && evidenceRecords.allSatisfy { !$0.isVerified }
    }

    var isVerified: Bool {
        !isFictional && evidenceRecords.contains(where: \.isVerified)
    }

    /// The date a human last verified this profile's primary source, if ever.
    var verificationDate: Date? {
        orderedEvidence.compactMap(\.verificationDate).max()
    }

    /// Confidence = the record's stated confidence, but **capped** by how it was
    /// obtained. Fictional data and unverified candidates never present above
    /// exploratory; a verified record decays toward moderate as it ages.
    var evidenceConfidence: EvidenceConfidence {
        guard let primary = primaryEvidence else { return .exploratory }
        if primary.provenance == .fictionalSample { return .exploratory }
        guard let verifiedAt = primary.verificationDate else { return .exploratory }
        let days = Calendar.current.dateComponents([.day], from: verifiedAt, to: Date()).day ?? 9_999
        if days > 180 { return min(primary.confidence, .moderate) }
        return primary.confidence
    }
}
