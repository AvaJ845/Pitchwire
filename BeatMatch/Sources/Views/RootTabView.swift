import SwiftUI

struct RootTabView: View {
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
    }
}
