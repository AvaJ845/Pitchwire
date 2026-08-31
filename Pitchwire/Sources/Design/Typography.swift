import SwiftUI

/// Pitchwire's type voice. Chrome, controls and body stay in San Francisco —
/// the platform default, and the right call for UI. Editorial *display* type —
/// screen titles, a journalist's name, the "what's your story" prompt — is set
/// in **New York**, the serif that ships with the system. The product is
/// editorial-relevance research; the headlines should read like a masthead, not
/// a settings pane. New York is a real system face, so Dynamic Type, weights and
/// optical sizing all still work.
extension Font {
    /// Screen-defining headline — the one big line at the top of a flow.
    static func editorialLargeTitle(_ weight: Font.Weight = .bold) -> Font {
        .system(.largeTitle, design: .serif).weight(weight)
    }

    /// Navigation-level / card-defining title.
    static func editorialTitle(_ weight: Font.Weight = .bold) -> Font {
        .system(.title2, design: .serif).weight(weight)
    }

    /// A name or a short editorial label inline in content.
    static func editorialHeadline(_ weight: Font.Weight = .semibold) -> Font {
        .system(.headline, design: .serif).weight(weight)
    }
}
