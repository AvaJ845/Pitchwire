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

    // Text
    static let ink = Color(light: 0x0B1B2E, dark: 0xF2F5F8)
    static let inkSecondary = Color(light: 0x5B6672, dark: 0x9AA6B2)
    static let inkTertiary = Color(light: 0x8B95A1, dark: 0x6C7784)

    // Confidence tiers (match strength)
    static func tier(_ tier: ConfidenceTier) -> Color {
        switch tier {
        case .excellent: return Color(light: 0x0E8C7E, dark: 0x2CD3BE)
        case .strong:    return Color(light: 0x2563C9, dark: 0x6BA5FF)
        case .possible:  return Color(light: 0x8B95A1, dark: 0x8B95A1)
        }
    }

    // Evidence confidence (data freshness)
    static func evidence(_ c: EvidenceConfidence) -> Color {
        switch c {
        case .high:        return Color(light: 0x1E9E63, dark: 0x4CD08A)
        case .moderate:    return Color(light: 0xB8860B, dark: 0xE6B450)
        case .exploratory: return Color(light: 0x8B95A1, dark: 0x8B95A1)
        }
    }

    static let warning = Color(light: 0xB8860B, dark: 0xE6B450)
    static let danger = Color(light: 0xC23B3B, dark: 0xFF6B6B)
}

enum Metrics {
    static let cardRadius: CGFloat = 16
    static let controlRadius: CGFloat = 12
    static let gutter: CGFloat = 20
}
