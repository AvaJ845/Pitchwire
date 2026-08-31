import SwiftUI
import SwiftData

struct CampaignsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Campaign.createdAt, order: .reverse) private var campaigns: [Campaign]

    var body: some View {
        NavigationStack {
            Group {
                if campaigns.isEmpty {
                    ContentUnavailableView {
                        Label("No campaigns yet", systemImage: "square.stack.3d.up")
                    } description: {
                        Text("Analyze a story from Home to start one.")
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(campaigns) { campaign in
                                NavigationLink {
                                    MatchListView(campaign: campaign)
                                } label: {
                                    CampaignRow(campaign: campaign)
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button("Delete", role: .destructive) {
                                        withAnimation { modelContext.delete(campaign) }
                                        try? modelContext.save()
                                    }
                                }
                            }
                        }
                        .padding(Metrics.gutter)
                    }
                }
            }
            .screenBackground()
            .navigationTitle("Campaigns")
        }
    }
}
