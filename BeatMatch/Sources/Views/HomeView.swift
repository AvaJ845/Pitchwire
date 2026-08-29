import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AIClient.self) private var aiClient
    @Environment(Entitlements.self) private var entitlements

    @State private var storyText: String = ""
    @State private var isAnalyzing = false
    @State private var activeCampaign: Campaign?
    @State private var errorMessage: String?

    private var analysisService: StoryAnalysisService {
        DefaultStoryAnalysisService(ai: aiClient)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("What's your story?")
                        .font(.largeTitle.bold())

                    Text("Paste your launch story, press release, or announcement. We'll tell you who's most likely to care, why, and what to say.")
                        .foregroundStyle(.secondary)

                    TextEditor(text: $storyText)
                        .frame(minHeight: 220)
                        .padding(8)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))

                    if let errorMessage {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .font(.footnote)
                    }

                    Button {
                        Task { await analyze() }
                    } label: {
                        if isAnalyzing {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Analyze")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(storyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isAnalyzing)

                    AllowanceFooter(key: .storyAnalysis)
                }
                .padding()
            }
            .navigationTitle("Pitchwire")
            .navigationDestination(item: $activeCampaign) { campaign in
                StorySummaryView(campaign: campaign)
            }
        }
    }

    private func analyze() async {
        errorMessage = nil

        guard entitlements.consume(.storyAnalysis) else {
            errorMessage = "You've used all \(entitlements.plan.limit(for: .storyAnalysis) ?? 0) story analyses on the \(entitlements.plan.tier.displayName) plan this period."
            return
        }

        isAnalyzing = true
        defer { isAnalyzing = false }

        do {
            let story = Story(rawText: storyText, sourceType: .pastedText)
            let analysis = try await analysisService.analyze(rawText: storyText)
            story.apply(analysis)

            let campaign = Campaign(name: analysis.theme, story: story)
            modelContext.insert(campaign)
            try modelContext.save()

            storyText = ""
            activeCampaign = campaign
        } catch {
            errorMessage = "Couldn't analyze that story: \(error.localizedDescription)"
        }
    }
}

/// "N of M story analyses left this period" — reads through Entitlements, never
/// the plan directly.
struct AllowanceFooter: View {
    @Environment(Entitlements.self) private var entitlements
    let key: UsageKey

    var body: some View {
        if entitlements.isUnlimited(key) {
            Text("\(key.displayName): unlimited on \(entitlements.plan.tier.displayName)")
                .font(.footnote)
                .foregroundStyle(.secondary)
        } else if let remaining = entitlements.remaining(key) {
            let limit = entitlements.plan.limit(for: key) ?? 0
            Text("\(remaining) of \(limit) \(key.displayName.lowercased()) left this period")
                .font(.footnote)
                .foregroundStyle(remaining == 0 ? .orange : .secondary)
        }
    }
}
