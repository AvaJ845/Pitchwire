import SwiftUI
import SwiftData

@main
struct BeatMatchApp: App {
    @State private var aiClient: AIClient
    @State private var entitlements: Entitlements
    @State private var llmLog: LLMLog

    let sharedModelContainer: ModelContainer

    init() {
        #if DEBUG
        let resetForTests = ProcessInfo.processInfo.arguments.contains("-uitest-reset")
        #else
        let resetForTests = false   // launch args are honoured in DEBUG only
        #endif

        // Developer LLM log — DEBUG-only viewer, capture toggle in Settings.
        if resetForTests {
            for key in ["llmlog.capture", "llmlog.capture.payloads"] {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }
        let log = LLMLog()
        llmLog = log

        // AI layer — reads Config/AIConfig.plist (gitignored) if present, else
        // fully offline on deterministic fallbacks. No provider key is ever in
        // the app — only a scoped client token for our own backend.
        aiClient = AIClient(configuration: .fromBundle(), log: log)

        // Entitlements — one config object, swappable store. Feature code never
        // checks the plan directly.
        let entitlementStore = LocalEntitlementStore()
        if resetForTests { entitlementStore.resetUsage() }
        entitlements = Entitlements(store: entitlementStore)

        sharedModelContainer = Self.makeContainer(wipeFirst: resetForTests)
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environment(aiClient)
                .environment(entitlements)
                .environment(llmLog)
        }
        .modelContainer(sharedModelContainer)
    }

    private static func makeContainer(wipeFirst: Bool) -> ModelContainer {
        let schema = Schema([
            Story.self,
            Campaign.self,
            MediaTarget.self,
            Outlet.self,
            JournalistProfile.self,
            MatchExplanation.self,
            PitchDraft.self,
            EditorialEvidenceRecord.self,
            CoverageEvidence.self,
            FollowUpTask.self,
            RemovalRequest.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        func wipeStore() {
            let url = configuration.url
            for suffix in ["", "-shm", "-wal"] {
                try? FileManager.default.removeItem(
                    at: url.deletingPathExtension().appendingPathExtension("store\(suffix)")
                )
            }
            try? FileManager.default.removeItem(at: url)
        }

        if wipeFirst { wipeStore() }

        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            // Pre-1.0, local-only, no accounts: if the on-disk store predates a
            // schema change we can't migrate, wipe it rather than crash on launch.
            wipeStore()
            do {
                return try ModelContainer(for: schema, configurations: [configuration])
            } catch {
                fatalError("Could not create Pitchwire's SwiftData container: \(error)")
            }
        }
    }
}
