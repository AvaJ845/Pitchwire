import SwiftUI
import SwiftData

struct CampaignsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Campaign.createdAt, order: .reverse) private var campaigns: [Campaign]
    @State private var pendingDelete: Campaign?

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
                                    Button("Delete campaign", role: .destructive) {
                                        pendingDelete = campaign
                                    }
                                }
                            }
                        }
                        .padding(Metrics.gutter)
                        .readableWidth()
                    }
                }
            }
            .screenBackground()
            .navigationTitle("Campaigns")
            .confirmationDialog(
                "Delete “\(pendingDelete?.name ?? "")”?",
                isPresented: .init(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    if let campaign = pendingDelete {
                        Haptics.warning()
                        withAnimation { modelContext.delete(campaign) }
                        try? modelContext.save()
                    }
                    pendingDelete = nil
                }
                Button("Cancel", role: .cancel) { pendingDelete = nil }
            } message: {
                Text("This removes the story, its matches, drafts, and follow-ups. It can't be undone.")
            }
        }
    }
}
