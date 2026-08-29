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
            // Pre-1.0, local-only, no accounts: if the on-disk store predates a schema
            // change we can't migrate, wipe it and start clean rather than crash on launch.
            // (A real migration plan replaces this before there is user data worth keeping.)
            if let url = configuration.url as URL?, FileManager.default.fileExists(atPath: url.path) {
                try? FileManager.default.removeItem(at: url)
                try? FileManager.default.removeItem(at: url.deletingPathExtension().appendingPathExtension("store-shm"))
                try? FileManager.default.removeItem(at: url.deletingPathExtension().appendingPathExtension("store-wal"))
            }
            do {
                return try ModelContainer(for: schema, configurations: [configuration])
            } catch {
                fatalError("Could not create Pitchwire's SwiftData container: \(error)")
            }
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootTabView()
        }
        .modelContainer(sharedModelContainer)
    }
}
