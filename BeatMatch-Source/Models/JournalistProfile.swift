import Foundation
import SwiftData

@Model
final class JournalistProfile {
    var id: UUID
    var name: String
    var beatTopics: [String]
    var recentBylineTitles: [String]
    var outlet: Outlet?
    var provenance: ProvenanceRecord?

    init(name: String, beatTopics: [String] = [], recentBylineTitles: [String] = [], outlet: Outlet? = nil) {
        self.id = UUID()
        self.name = name
        self.beatTopics = beatTopics
        self.recentBylineTitles = recentBylineTitles
        self.outlet = outlet
    }
}
