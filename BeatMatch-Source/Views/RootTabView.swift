import SwiftUI

struct RootTabView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("Home", systemImage: "sparkles") }

            CampaignsView()
                .tabItem { Label("Campaigns", systemImage: "folder") }

            DraftsView()
                .tabItem { Label("Drafts", systemImage: "envelope") }

            ProfileView()
                .tabItem { Label("Profile", systemImage: "person.circle") }
        }
    }
}
