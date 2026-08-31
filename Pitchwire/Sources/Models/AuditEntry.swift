import Foundation
import SwiftData

/// One line in the Research Lab's accountability trail — who did what, to which
/// profile, when. Written by every `LabActions` mutation. Pitchwire's editorial
/// data is only as trustworthy as the record of how it got verified; this is
/// that record.
@Model
final class AuditEntry {
    var id: UUID
    var at: Date
    var action: String      // "verify", "un-verify", "reject", "restore", "claim", "article +", "article −", "removal resolved"
    var subject: String      // the profile (or removal request) acted on
    var reviewer: String     // initials, "—" when not supplied
    var detail: String       // a short human summary of what changed

    init(action: String, subject: String, reviewer: String, detail: String = "") {
        self.id = UUID()
        self.at = Date()
        self.action = action
        self.subject = subject
        let who = reviewer.trimmingCharacters(in: .whitespacesAndNewlines)
        self.reviewer = who.isEmpty ? "—" : who
        self.detail = detail
    }
}
