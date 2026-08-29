import SwiftUI
import SwiftData

@main
struct BeatMatchApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Story.self,
            Campaign.self,
            MediaTarget.self,
            Outlet.self,
            JournalistProfile.self,
            MatchExplanation.self,
            PitchDraft.self,
            ProvenanceRecord.self,
            FollowUpTask.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Could not create BeatMatch's SwiftData container: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootTabView()
        }
        .modelContainer(sharedModelContainer)
    }
}
