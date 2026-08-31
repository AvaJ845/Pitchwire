import SwiftUI
import SwiftData

struct ProfileView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(Entitlements.self) private var entitlements
    @Environment(AIClient.self) private var aiClient
    @State private var exportURL: URL?
    #if DEBUG
    @Environment(LLMLog.self) private var llmLog
    #endif

    var body: some View {
        NavigationStack {
            List {
                Section("Plan") {
                    LabeledContent("Current plan", value: entitlements.plan.tier.displayName)
                    ForEach(UsageKey.allCases, id: \.self) { key in
                        LabeledContent(key.displayName) {
                            if entitlements.isUnlimited(key) {
                                Text("Unlimited").foregroundStyle(.secondary)
                            } else {
                                let limit = entitlements.plan.limit(for: key) ?? 0
                                Text("\(entitlements.used(key)) / \(limit) this period")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Section("Included features") {
                    ForEach(FeatureKey.allCases, id: \.self) { feature in
                        HStack {
                            Text(featureName(feature))
                            Spacer()
                            Image(systemName: entitlements.can(feature) ? "checkmark.circle.fill" : "lock.fill")
                                .foregroundStyle(entitlements.can(feature) ? .green : .secondary)
                        }
                    }
                }

                Section("AI") {
                    LabeledContent("Status", value: aiClient.isConfigured ? "Connected" : "On-device only")
                    Text("Analysis and drafting run through a provider-independent gateway. The model is chosen server-side; no AI keys are stored in the app.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section {
                    Button {
                        let json = WorkspaceExporter.json(modelContext)
                        let url = FileManager.default.temporaryDirectory
                            .appendingPathComponent("pitchwire-workspace.json")
                        try? json.data(using: .utf8)?.write(to: url)
                        exportURL = url
                    } label: {
                        Label("Export my data", systemImage: "square.and.arrow.up")
                    }
                    if let exportURL {
                        ShareLink(item: exportURL) { Label("Share export", systemImage: "doc") }
                    }
                } header: {
                    Text("Your data")
                } footer: {
                    Text("Everything is stored on this device only. Export a portable JSON of your campaigns, matches, drafts and follow-ups any time.")
                }

                Section("About Pitchwire") {
                    Text("An editorial-relevance research assistant. See docs/DIRECTION.md for the product direction and what's next.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                #if DEBUG
                Section {
                    NavigationLink { ResearchLabView() } label: {
                        Label("Research Lab", systemImage: "flask")
                    }
                    Toggle("Capture LLM logs", isOn: Binding(
                        get: { llmLog.isCapturing },
                        set: { llmLog.isCapturing = $0 }
                    ))
                    NavigationLink {
                        DebugLLMLogView()
                    } label: {
                        LabeledContent("LLM log", value: "\(llmLog.failures.count) failures")
                    }
                } header: {
                    Text("Developer")
                } footer: {
                    Text("DEBUG builds only. The Research Lab is the human verify/approve step for editorial evidence. The LLM log records every AI call and failover — metadata only, secrets redacted.")
                }

                Section {
                    Toggle("Capture prompts & responses", isOn: Binding(
                        get: { llmLog.isCapturingPayloads },
                        set: { llmLog.isCapturingPayloads = $0 }
                    ))
                } footer: {
                    Text("Writes full prompts and responses to the device console (Xcode / Console.app when attached — not sysdiagnose). Prompts contain your unpublished story text. Off by default.")
                }
                #endif
            }
            .navigationTitle("Profile")
        }
    }

    private func featureName(_ feature: FeatureKey) -> String {
        switch feature {
        case .savedCampaigns:    return "Saved campaigns"
        case .followUpReminders: return "Follow-up reminders"
        case .exportPitch:       return "Export pitches"
        case .teamWorkspace:     return "Team workspace"
        case .multiClient:       return "Multi-client campaigns"
        }
    }
}
