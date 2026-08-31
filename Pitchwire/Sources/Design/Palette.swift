import SwiftUI

extension Color {
    init(hex: UInt) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }

    init(light: UInt, dark: UInt) {
        self.init(uiColor: UIColor { traits in
            let hex = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(
                red: CGFloat((hex >> 16) & 0xFF) / 255,
                green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255,
                alpha: 1
            )
        })
    }
}

/// Pitchwire's colour system. Brand navy + teal from the app icon, with
/// semantic tokens that adapt to light and dark.
enum Palette {
    // Brand
    static let navy = Color(hex: 0x0B1B2E)
    static let accent = Color(light: 0x0E8C7E, dark: 0x2CD3BE)      // teal
    static let accentSoft = Color(light: 0xE2F4F1, dark: 0x123A36)

    // Surfaces
    static let canvas = Color(light: 0xF4F5F7, dark: 0x0C1116)
    static let surface = Color(light: 0xFFFFFF, dark: 0x171C23)
    static let surfaceRaised = Color(light: 0xFFFFFF, dark: 0x1E252E)
    static let hairline = Color(light: 0xE7E9EE, dark: 0x2A313B)

    // Text. inkTertiary is still the lightest of the three but now clears WCAG
    // AA (~4.7:1 on `canvas`) — it carries load-bearing copy (allowance counts,
    // verification dates), so it can't be decorative-grey.
    static let ink = Color(light: 0x0B1B2E, dark: 0xF2F5F8)
    static let inkSecondary = Color(light: 0x53606D, dark: 0x9AA6B2)
    static let inkTertiary = Color(light: 0x676D79, dark: 0x7E8894)

    // Confidence tiers (match strength) — teal → blue → slate.
    static func tier(_ tier: ConfidenceTier) -> Color {
        switch tier {
        case .excellent: return Color(light: 0x0E8C7E, dark: 0x2CD3BE)
        case .strong:    return Color(light: 0x2563C9, dark: 0x6BA5FF)
        case .possible:  return Color(light: 0x6E7A88, dark: 0x7C8A99)   // slate — distinct from evidence(.exploratory)
        }
    }

    // Evidence confidence (data freshness) — green → violet → warm grey.
    // Deliberately a different hue family from `tier` and from `warning`, so
    // "medium confidence" never reads as "caution".
    static func evidence(_ c: EvidenceConfidence) -> Color {
        switch c {
        case .high:        return Color(light: 0x1E9E63, dark: 0x4CD08A)
        case .moderate:    return Color(light: 0x7A5AF8, dark: 0x9B87FF)   // violet, not goldenrod
        case .exploratory: return Color(light: 0x9AA0A6, dark: 0x8C939B)   // warm grey
        }
    }

    // Amber — only ever "something needs attention". Light variant darkened to
    // ~4.9:1 on `canvas` because it's used as *text* (errors, overdue, "0 left").
    static let warning = Color(light: 0x8A6300, dark: 0xE6B450)
    static let danger = Color(light: 0xC23B3B, dark: 0xFF6B6B)
}

enum Metrics {
    static let cardRadius: CGFloat = 16
    static let controlRadius: CGFloat = 12
    static let gutter: CGFloat = 20
}
