import SwiftUI

struct RootTabView: View {
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("Home", systemImage: "sparkles") }

            CampaignsView()
                .tabItem { Label("Campaigns", systemImage: "square.stack.3d.up") }

            DraftsView()
                .tabItem { Label("Drafts", systemImage: "paperplane") }

            ProfileView()
                .tabItem { Label("Profile", systemImage: "person.crop.circle") }
        }
        .tint(Palette.accent)
        .task { JournalistDirectory.ensureSeeded(modelContext) }
    }
}
