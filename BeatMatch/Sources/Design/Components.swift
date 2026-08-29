import SwiftUI

// MARK: - Card

/// The one card surface used across the app: rounded, hairline-bordered,
/// adaptive fill. Replaces ad-hoc `GroupBox` / `RoundedRectangle` styling.
struct Card<Content: View>: View {
    var padding: CGFloat = 16
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous)
                    .strokeBorder(Palette.hairline, lineWidth: 1)
            )
    }
}

// MARK: - Section label

struct SectionLabel: View {
    let title: String
    var trailing: String?

    var body: some View {
        HStack {
            Text(title)
                .font(.caption.weight(.semibold))
                .textCase(.uppercase)          // display only — a11y label keeps original case
                .tracking(0.6)
                .foregroundStyle(Palette.inkTertiary)
            Spacer()
            if let trailing {
                Text(trailing)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Palette.inkTertiary)
            }
        }
    }
}

// MARK: - Monogram

/// Initials in a tinted circle — a stand-in for a journalist avatar we don't
/// (and shouldn't) fetch. Colour is derived from the name so it's stable.
struct Monogram: View {
    let name: String
    var size: CGFloat = 44

    private var initials: String {
        let parts = name.split(separator: " ")
        let letters = parts.prefix(2).compactMap { $0.first }
        return String(letters).uppercased()
    }

    private var tint: Color {
        let palette: [UInt] = [0x0E8C7E, 0x2563C9, 0x8A5CF6, 0xC2410C, 0xB8860B, 0x0891B2]
        let idx = abs(name.hashValue) % palette.count
        return Color(hex: palette[idx])
    }

    var body: some View {
        Text(initials)
            .font(.system(size: size * 0.38, weight: .semibold, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(
                LinearGradient(
                    colors: [tint, tint.opacity(0.78)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ),
                in: Circle()
            )
            .accessibilityHidden(true)
    }
}

// MARK: - Pills

struct Tag: View {
    let text: String
    var icon: String?
    var color: Color = Palette.inkSecondary

    var body: some View {
        HStack(spacing: 4) {
            if let icon { Image(systemName: icon).font(.caption2) }
            Text(text)
        }
        .font(.caption.weight(.medium))
        .foregroundStyle(color)
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(color.opacity(0.12), in: Capsule())
    }
}

struct ConfidencePill: View {
    let tier: ConfidenceTier

    var body: some View {
        Text(tier.shortLabel)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Palette.tier(tier), in: Capsule())
            .accessibilityLabel(tier.displayName)
    }
}

struct EvidenceDot: View {
    let confidence: EvidenceConfidence
    var showsLabel = true

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(Palette.evidence(confidence))
                .frame(width: 7, height: 7)
            if showsLabel {
                Text(confidence.label)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Palette.inkSecondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Evidence: \(confidence.label)")
    }
}

// MARK: - Primary button

struct PitchwireButtonStyle: ButtonStyle {
    var prominent = true
    @Environment(\.isEnabled) private var isEnabled

    private var fill: Color {
        prominent ? Palette.accent.opacity(isEnabled ? 1 : 0.4) : Palette.accentSoft
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .foregroundStyle(prominent ? Color.white : Palette.accent)
            .background(fill, in: RoundedRectangle(cornerRadius: Metrics.controlRadius, style: .continuous))
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.99 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PitchwireButtonStyle {
    static var pitchwire: PitchwireButtonStyle { PitchwireButtonStyle(prominent: true) }
    static var pitchwireQuiet: PitchwireButtonStyle { PitchwireButtonStyle(prominent: false) }
}

// MARK: - Screen background

struct ScreenBackground: ViewModifier {
    func body(content: Content) -> some View {
        content.background(Palette.canvas.ignoresSafeArea())
    }
}

extension View {
    func screenBackground() -> some View { modifier(ScreenBackground()) }
}

// MARK: - Tier display helpers

extension ConfidenceTier {
    var shortLabel: String {
        switch self {
        case .excellent: return "Excellent"
        case .strong: return "Strong"
        case .possible: return "Possible"
        }
    }
}
