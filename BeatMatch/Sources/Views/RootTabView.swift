import SwiftUI

struct RootTabView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("pitchwire.hasOnboarded") private var hasOnboarded = false
    @State private var showOnboarding = false

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
        .task {
            if !hasOnboarded { showOnboarding = true }
            JournalistDirectory.ensureSeeded(modelContext)
            // Warm the on-device semantic vectors in the background so the first
            // "Find journalists" is instant. Background priority — it yields to
            // anything the user is doing.
            await MatchRunner.warmDirectory(context: modelContext, priority: .utility)
        }
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingView { seedExample in
                if seedExample { UserDefaults.standard.set(true, forKey: "pitchwire.seedExampleOnce") }
                hasOnboarded = true
                showOnboarding = false
            }
            .interactiveDismissDisabled()
        }
    }
}
