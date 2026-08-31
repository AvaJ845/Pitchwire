import SwiftUI

/// A campaign in a list — story theme, when, and how far it's got.
struct CampaignRow: View {
    let campaign: Campaign

    private var matchCount: Int { campaign.mediaTargets.count }
    private var draftCount: Int { campaign.pitchDrafts.count }
    private var sentCount: Int { campaign.pitchDrafts.filter { $0.status == .markedSent }.count }

    var body: some View {
        Card {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Palette.accentSoft)
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: "doc.text")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(Palette.accent)
                    )

                VStack(alignment: .leading, spacing: 3) {
                    Text(campaign.name)
                        .font(.headline)
                        .foregroundStyle(Palette.ink)
                    HStack(spacing: 6) {
                        Text(campaign.createdAt.formatted(.relative(presentation: .named)))
                        if matchCount > 0 {
                            Text("·")
                            Text("\(matchCount) matches")
                        }
                        if sentCount > 0 {
                            Text("·")
                            Text("\(sentCount) sent")
                        } else if draftCount > 0 {
                            Text("·")
                            Text("\(draftCount) drafts")
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(Palette.inkTertiary)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Palette.inkTertiary)
            }
        }
    }
}

/// A ranked journalist in the match list.
struct MatchRow: View {
    let target: MediaTarget

    var body: some View {
        Card {
            HStack(alignment: .top, spacing: 12) {
                Monogram(name: target.journalist?.name ?? "?", size: 42)

                VStack(alignment: .leading, spacing: 5) {
                    HStack(alignment: .firstTextBaseline, spacing: 5) {
                        if target.status == .shortlisted {
                            Image(systemName: "star.fill")
                                .font(.caption2)
                                .foregroundStyle(Palette.accent)
                                .accessibilityLabel("Shortlisted")
                        }
                        Text(target.journalist?.name ?? "Unknown")
                            .font(.headline)
                            .foregroundStyle(Palette.ink)
                        Spacer(minLength: 8)
                        ConfidencePill(tier: target.confidenceTier)
                    }

                    HStack(spacing: 6) {
                        if let outlet = target.journalist?.outlet?.name {
                            Text(outlet)
                                .font(.subheadline)
                                .foregroundStyle(Palette.inkSecondary)
                        }
                        if let state = target.journalist?.evidenceState {
                            Tag(text: state.tagText, icon: state.tagIcon, color: state.tagColor)
                        }
                        if let c = target.journalist?.evidenceConfidence {
                            EvidenceDot(confidence: c, showsLabel: false)
                        }
                    }

                    if let reason = target.explanation?.reasonText {
                        Text(reason)
                            .font(.footnote)
                            .foregroundStyle(Palette.inkSecondary)
                            .lineLimit(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }
}

/// A pitch draft in a list.
struct DraftRow: View {
    let draft: PitchDraft

    var body: some View {
        Card {
            HStack(spacing: 12) {
                Monogram(name: draft.mediaTarget?.journalist?.name ?? "?", size: 40)
                VStack(alignment: .leading, spacing: 3) {
                    Text(draft.subject)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Palette.ink)
                        .lineLimit(2)
                    Text(draft.mediaTarget?.journalist?.name ?? "Unknown recipient")
                        .font(.caption)
                        .foregroundStyle(Palette.inkTertiary)
                }
                Spacer(minLength: 0)
                if draft.status == .markedSent {
                    Tag(text: "Sent", icon: "checkmark", color: Palette.evidence(.high))
                } else {
                    Tag(text: "Draft", color: Palette.inkSecondary)
                }
            }
        }
    }
}
