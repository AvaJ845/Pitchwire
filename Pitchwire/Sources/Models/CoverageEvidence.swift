import Foundation
import SwiftData

/// One real article that evidences an editorial professional's relevance. The
/// user can open `url` and check it — this is what "traceable to source evidence"
/// means in practice.
///
/// No author contact data lives here. Just: what they wrote, where, when, and
/// which story topics it speaks to.
@Model
final class CoverageEvidence {
    var id: UUID
    var title: String
    var url: String
    var publishedAt: Date?
    /// Which of the story's topics this article is evidence for — used by the
    /// relevance engine's topic / repeated-coverage signals.
    var topics: [String]
    var outletName: String?

    var record: EditorialEvidenceRecord?

    init(
        title: String,
        url: String,
        publishedAt: Date? = nil,
        topics: [String] = [],
        outletName: String? = nil
    ) {
        self.id = UUID()
        self.title = title
        self.url = url
        self.publishedAt = publishedAt
        self.topics = topics
        self.outletName = outletName
    }
}

extension CoverageEvidence {
    /// "Jul 2026" — nil when the date is unknown (never guessed).
    var publishedLabel: String? {
        publishedAt?.formatted(.dateTime.month(.abbreviated).year())
    }

    var host: String? {
        URL(string: url)?.host()?.replacingOccurrences(of: "www.", with: "")
    }
}
