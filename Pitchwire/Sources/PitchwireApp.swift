import SwiftUI
import SwiftData

@main
struct PitchwireApp: App {
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
            for key in ["llmlog.capture", "llmlog.capture.payloads", "pitchwire.seedExampleOnce"] {
                UserDefaults.standard.removeObject(forKey: key)
            }
            // Tests land straight in the app; `-uitest-onboarding` opts back into
            // the first-launch intro (OnboardingUITests).
            #if DEBUG
            let wantsOnboarding = ProcessInfo.processInfo.arguments.contains("-uitest-onboarding")
            UserDefaults.standard.set(!wantsOnboarding, forKey: "pitchwire.hasOnboarded")
            #endif
        }
        let log = LLMLog()
        llmLog = log

        // AI layer — reads Config/AIConfig.plist (gitignored) if present, else
        // fully offline on deterministic fallbacks. No provider key is ever in
        // the app — only a scoped client token for our own backend.
        aiClient = {
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-uitest-mock-ai") {
                return AIClient(
                    configuration: AIConfiguration(baseURL: URL(string: "https://mock.pitchwire.local")!,
                                                   clientToken: "uitest"),
                    log: log,
                    gatewayOverride: MockAIGateway())
            }
            #endif
            return AIClient(configuration: .fromBundle(), log: log)
        }()

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
            RemovalRequest.self,
            AuditEntry.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        let storeURLs: [URL] = {
            let base = configuration.url.deletingPathExtension()
            return ["store", "store-shm", "store-wal"].map { base.appendingPathExtension($0) }
                + [configuration.url]
        }()

        /// Move the store aside — never delete it outright. SwiftData is
        /// additive-migration only; an incompatible change (a rename / retype)
        /// otherwise crashes on launch. Pre-1.0 we recover by parking the old
        /// store in a dated folder the user can retrieve, not by shredding it.
        func parkStore() {
            let stamp = ISO8601DateFormatter().string(from: Date())
                .replacingOccurrences(of: ":", with: "-")
            let backupDir = (try? FileManager.default.url(
                for: .applicationSupportDirectory, in: .userDomainMask,
                appropriateFor: nil, create: true))?
                .appendingPathComponent("PitchwireBackups/\(stamp)", isDirectory: true)
            if let backupDir {
                try? FileManager.default.createDirectory(at: backupDir, withIntermediateDirectories: true)
            }
            for url in storeURLs where FileManager.default.fileExists(atPath: url.path) {
                if let dest = backupDir?.appendingPathComponent(url.lastPathComponent) {
                    try? FileManager.default.moveItem(at: url, to: dest)
                } else {
                    try? FileManager.default.removeItem(at: url)   // last resort
                }
            }
            print("[Pitchwire] incompatible store parked at \(backupDir?.path ?? "(removed)")")
        }

        if wipeFirst { parkStore() }

        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            parkStore()
            do {
                return try ModelContainer(for: schema, configurations: [configuration])
            } catch {
                fatalError("Could not create Pitchwire's SwiftData container: \(error)")
            }
        }
    }
}
