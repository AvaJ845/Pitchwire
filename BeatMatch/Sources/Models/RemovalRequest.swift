import Foundation
import SwiftData

/// A request to review or remove an editorial profile. Raised from the profile's
/// "Report an issue" button. Not linked to the profile by a relationship — the
/// profile may be deleted before the request is resolved. No personal data.
///
/// Today this is a local queue a researcher works in the Research Lab. Before any
/// public release it must also POST to a monitored inbox with a real 48-hour SLA
/// (see `docs/RESEARCH_LAB.md`).
@Model
final class RemovalRequest {
    var id: UUID
    var journalistName: String
    var journalistID: UUID
    var reason: String
    var requestedAt: Date
    var resolvedAt: Date?
    var resolution: String?

    var isOpen: Bool { resolvedAt == nil }

    init(journalistName: String, journalistID: UUID, reason: String) {
        self.id = UUID()
        self.journalistName = journalistName
        self.journalistID = journalistID
        self.reason = reason
        self.requestedAt = Date()
    }
}
