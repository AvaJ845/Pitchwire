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
        // A *stable* hash — `String.hashValue` is per-process randomised, so it
        // would repaint every avatar on each launch. FNV-1a over the scalars.
        var h: UInt64 = 0xcbf29ce484222325
        for byte in name.utf8 { h = (h ^ UInt64(byte)) &* 0x100000001b3 }
        return Color(hex: palette[Int(h % UInt64(palette.count))])
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

// MARK: - Evidence & verification

/// The three honest states a profile can be in. Drives every "is this real?"
/// surface so the language never drifts.
enum ProfileEvidenceState {
    case verified          // a human reviewed the sources
    case candidate         // real person, evidence not yet human-verified
    case demo              // fictional stand-in
    case rejected          // a researcher rejected it (Lab only — never in matching)

    var tagText: String {
        switch self {
        case .verified:  return "Verified"
        case .candidate: return "Candidate"
        case .demo:      return "Demo"
        case .rejected:  return "Rejected"
        }
    }

    var tagColor: Color {
        switch self {
        case .verified:  return Palette.evidence(.high)
        case .candidate: return Palette.accent
        case .demo:      return Palette.warning
        case .rejected:  return Palette.inkTertiary
        }
    }

    var tagIcon: String {
        switch self {
        case .verified:  return "checkmark.seal.fill"
        case .candidate: return "magnifyingglass"
        case .demo:      return "flask.fill"
        case .rejected:  return "xmark.circle"
        }
    }
}

extension JournalistProfile {
    var evidenceState: ProfileEvidenceState {
        if isRejected { return .rejected }
        if isFictional { return .demo }
        if isVerified { return .verified }
        return .candidate
    }
}

/// The verification line in the evidence card — a date when verified, an honest
/// "not yet verified" otherwise.
struct VerificationBadge: View {
    let state: ProfileEvidenceState
    var date: Date?

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: state.tagIcon).font(.caption2)
            Text(label)
        }
        .font(.caption.weight(.medium))
        .foregroundStyle(state.tagColor)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(label)
    }

    private var label: String {
        switch state {
        case .verified:
            let when = date?.formatted(date: .abbreviated, time: .omitted) ?? "recently"
            return "Verified \(when)"
        case .candidate:
            return "Not yet verified — candidate profile"
        case .demo:
            return "Fictional demo profile"
        case .rejected:
            return "Rejected in review"
        }
    }
}

/// One article row that opens its source. Falls back to plain text when there is
/// no URL (demo data).
struct EvidenceLinkRow: View {
    let title: String
    var dateLabel: String?
    var url: String?

    var body: some View {
        Group {
            if let url, let link = URL(string: url), !url.isEmpty {
                Link(destination: link) { content(external: true) }
                    .buttonStyle(.plain)
            } else {
                content(external: false)
            }
        }
    }

    private func content(external: Bool) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "doc.text")
                .font(.caption)
                .foregroundStyle(Palette.accent)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                if let dateLabel {
                    Text(dateLabel)
                        .font(.caption2)
                        .foregroundStyle(Palette.inkTertiary)
                }
            }
            Spacer(minLength: 0)
            if external {
                Image(systemName: "arrow.up.right")
                    .font(.caption2)
                    .foregroundStyle(Palette.inkTertiary)
                    .padding(.top, 2)
            }
        }
        .contentShape(Rectangle())
    }
}

// MARK: - Primary button

struct PitchwireButtonStyle: ButtonStyle {
    var prominent = true
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.99 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PitchwireButtonStyle {
    static var pitchwire: PitchwireButtonStyle { PitchwireButtonStyle(prominent: true) }
    static var pitchwireQuiet: PitchwireButtonStyle { PitchwireButtonStyle(prominent: false) }
}

// MARK: - Evidence notice

/// Shown above a match list to set expectations about the data behind it.
/// Honesty is a product surface, not a footnote.
struct EvidenceNoticeBanner: View {
    /// The strongest (least-verified) state present in the list.
    let state: ProfileEvidenceState
    var compact = false

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: state.tagIcon)
                .foregroundStyle(state.tagColor)
            VStack(alignment: .leading, spacing: 2) {
                Text(headline)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Palette.ink)
                if !compact {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(Palette.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(state.tagColor.opacity(0.10), in: RoundedRectangle(cornerRadius: Metrics.controlRadius, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private var headline: String {
        switch state {
        case .verified:  return "Verified editorial evidence"
        case .candidate: return "Candidate profiles — not yet verified"
        case .demo:      return "Demo data"
        case .rejected:  return "Rejected"
        }
    }

    private var detail: String {
        switch state {
        case .verified:
            return "Every match below is backed by editorial evidence a person has reviewed. Open any profile to see the sources."
        case .candidate:
            return "These are real editorial professionals compiled from public bylines, pending human verification. Check each profile's sources before you rely on it."
        case .demo:
            return "These profiles are fictional stand-ins — names, outlets and coverage are demo data, not real people."
        case .rejected:
            return "This profile was rejected in review."
        }
    }
}

// MARK: - Screen background

struct ScreenBackground: ViewModifier {
    func body(content: Content) -> some View {
        content.background(Palette.canvas.ignoresSafeArea())
    }
}

extension View {
    func screenBackground() -> some View { modifier(ScreenBackground()) }

    /// Caps a scroll view's content to a comfortable reading measure and centres
    /// it — a no-op on iPhone, keeps lines from stretching edge-to-edge on iPad.
    func readableWidth(_ max: CGFloat = 640) -> some View {
        frame(maxWidth: max).frame(maxWidth: .infinity)
    }
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
