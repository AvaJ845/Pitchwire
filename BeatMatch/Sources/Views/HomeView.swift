import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var storyText: String = ""
    @State private var isAnalyzing = false
    @State private var activeCampaign: Campaign?
    @State private var errorMessage: String?

    private let analysisService: StoryAnalysisService = StubStoryAnalysisService()
    private let matchingService: MatchingService = KeywordMatchingService()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("What's your story?")
                        .font(.largeTitle.bold())

                    Text("Paste your launch story, press release, or announcement. We'll find who's most likely to care.")
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
                }
                .padding()
            }
            .navigationTitle("Pitchwire")
            .navigationDestination(item: $activeCampaign) { campaign in
                MatchListView(campaign: campaign)
            }
        }
    }

    private func analyze() async {
        errorMessage = nil
        isAnalyzing = true
        defer { isAnalyzing = false }

        do {
            let story = Story(rawText: storyText, sourceType: .pastedText)
            let analysis = try await analysisService.analyze(rawText: storyText)
            story.theme = analysis.theme
            story.vertical = analysis.vertical
            story.region = analysis.region
            story.angle = analysis.angle
            story.urgency = analysis.urgency
            story.summary = analysis.summary
            story.analysisStatus = .analyzed

            let campaign = Campaign(name: analysis.theme, story: story)
            modelContext.insert(campaign)

            let pool = SampleJournalists.seedPool()
            let candidates = matchingService.match(analysis: analysis, against: pool)

            for candidate in candidates {
                modelContext.insert(candidate.journalist)
                if let outlet = candidate.journalist.outlet {
                    modelContext.insert(outlet)
                }
                modelContext.insert(candidate.explanation)

                let target = MediaTarget(
                    confidenceTier: candidate.confidenceTier,
                    confidenceScore: candidate.confidenceScore,
                    journalist: candidate.journalist,
                    explanation: candidate.explanation
                )
                target.campaign = campaign
                campaign.mediaTargets.append(target)
            }

            try modelContext.save()
            storyText = ""
            activeCampaign = campaign
        } catch {
            errorMessage = "Couldn't analyze that story: \(error.localizedDescription)"
        }
    }
}
