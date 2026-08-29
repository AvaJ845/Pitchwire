import SwiftUI
import SwiftData

struct CampaignsView: View {
    @Query(sort: \Campaign.createdAt, order: .reverse) private var campaigns: [Campaign]

    var body: some View {
        NavigationStack {
            List(campaigns) { campaign in
                NavigationLink {
                    MatchListView(campaign: campaign)
                } label: {
                    VStack(alignment: .leading) {
                        Text(campaign.name)
                            .font(.headline)
                        Text(campaign.createdAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Campaigns")
            .overlay {
                if campaigns.isEmpty {
                    ContentUnavailableView(
                        "No campaigns yet",
                        systemImage: "folder",
                        description: Text("Analyze a story from Home to start one.")
                    )
                }
            }
        }
    }
}
