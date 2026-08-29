import SwiftUI

struct MatchListView: View {
    let campaign: Campaign

    private var grouped: [(ConfidenceTier, [MediaTarget])] {
        let tiers: [ConfidenceTier] = [.excellent, .strong, .possible]
        return tiers.compactMap { tier in
            let matches = campaign.mediaTargets.filter { $0.confidenceTier == tier }
            return matches.isEmpty ? nil : (tier, matches.sorted { $0.confidenceScore > $1.confidenceScore })
        }
    }

    var body: some View {
        List {
            if let story = campaign.story {
                Section {
                    Text(story.summary ?? "")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } header: {
                    Text(story.theme ?? "Story")
                }
            }

            ForEach(grouped, id: \.0) { tier, targets in
                Section(tier.displayName) {
                    ForEach(targets) { target in
                        NavigationLink {
                            JournalistDetailView(target: target, campaign: campaign)
                        } label: {
                            MatchRow(target: target)
                        }
                    }
                }
            }

            if grouped.isEmpty {
                ContentUnavailableView(
                    "No matches yet",
                    systemImage: "person.crop.circle.badge.questionmark",
                    description: Text("This story didn't overlap with anyone in the sample pool.")
                )
            }
        }
        .navigationTitle(campaign.name)
    }
}

private struct MatchRow: View {
    let target: MediaTarget

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(target.journalist?.name ?? "Unknown")
                .font(.headline)
            if let outlet = target.journalist?.outlet?.name {
                Text(outlet)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            if let reason = target.explanation?.reasonText {
                Text(reason)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }
}
