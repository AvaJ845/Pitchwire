import Foundation
import SwiftData

@Model
final class ProvenanceRecord {
    var id: UUID
    var source: String
    var lastVerifiedAt: Date
    var pitchPreference: String?
    var issueReported: Bool

    init(source: String, lastVerifiedAt: Date = Date(), pitchPreference: String? = nil, issueReported: Bool = false) {
        self.id = UUID()
        self.source = source
        self.lastVerifiedAt = lastVerifiedAt
        self.pitchPreference = pitchPreference
        self.issueReported = issueReported
    }
}
