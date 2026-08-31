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
                    List {
                        ForEach(campaigns) { campaign in
                            ZStack {
                                NavigationLink { MatchListView(campaign: campaign) } label: { EmptyView() }.opacity(0)
                                CampaignRow(campaign: campaign)
                            }
                            .accessibilityElement(children: .combine)
                            .accessibilityAddTraits(.isButton)
                            .listRowInsets(EdgeInsets(top: 5, leading: Metrics.gutter, bottom: 5, trailing: Metrics.gutter))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) { pendingDelete = campaign } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
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
