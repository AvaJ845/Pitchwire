import Foundation
import SwiftData

@Model
final class Outlet {
    var id: UUID
    var name: String
    var url: String?
    var verticals: [String]

    init(name: String, url: String? = nil, verticals: [String] = []) {
        self.id = UUID()
        self.name = name
        self.url = url
        self.verticals = verticals
    }
}
