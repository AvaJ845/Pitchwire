import SwiftUI
import SwiftData

struct JournalistDetailView: View {
    @Environment(\.modelContext) private var modelContext
    let target: MediaTarget
    let campaign: Campaign

    @State private var draft: PitchDraft?
    @State private var isDrafting = false

    private let draftingService: PitchDraftingService = TemplatePitchDraftingService()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(target.journalist?.name ?? "Unknown")
                        .font(.title.bold())
                    if let outlet = target.journalist?.outlet?.name {
                        Text(outlet)
                            .foregroundStyle(.secondary)
                    }
                }

                if let reason = target.explanation?.reasonText {
                    GroupBox {
                        Text(reason)
                    } label: {
                        Text("Why this match")
                    }
                }

                if let bylines = target.journalist?.recentBylineTitles, !bylines.isEmpty {
                    GroupBox {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(bylines, id: \.self) { title in
                                Text("• \(title)")
                            }
                        }
                    } label: {
                        Text("Recent bylines")
                    }
                }

                if let provenance = target.journalist?.provenance {
                    GroupBox {
                        VStack(alignment: .leading, spacing: 6) {
                            Label(provenance.source, systemImage: "checkmark.seal")
                            Text("Last verified: \(provenance.lastVerifiedAt.formatted(date: .abbreviated, time: .omitted))")
                                .foregroundStyle(.secondary)
                            if let pref = provenance.pitchPreference {
                                Text("Pitch preference: \(pref)")
                                    .foregroundStyle(.secondary)
                            }
                            Button("Report an issue with this profile", role: .destructive) {
                                provenance.issueReported = true
                                try? modelContext.save()
                            }
                            .font(.footnote)
                            .disabled(provenance.issueReported)
                            if provenance.issueReported {
                                Text("Reported — thanks, we'll review this.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } label: {
                        Text("Provenance")
                    }
                }

                Button {
                    Task { await generateDraft() }
                } label: {
                    if isDrafting {
                        ProgressView()
                    } else {
                        Text("Draft pitch")
                    }
                }
                .buttonStyle(.borderedProminent)

                if let draft {
                    NavigationLink("View draft") {
                        PitchDraftView(draft: draft)
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Match")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func generateDraft() async {
        guard let journalist = target.journalist, let story = campaign.story else { return }
        isDrafting = true
        defer { isDrafting = false }

        let analysis = story.analysisResult
        let candidate = MatchCandidate(
            journalist: journalist,
            confidenceTier: target.confidenceTier,
            confidenceScore: target.confidenceScore,
            explanation: target.explanation ?? MatchExplanation(reasonText: "")
        )

        do {
            let newDraft = try await draftingService.draft(story: analysis, rawText: story.rawText, for: candidate)
            newDraft.mediaTarget = target
            newDraft.campaign = campaign
            modelContext.insert(newDraft)
            campaign.pitchDrafts.append(newDraft)
            try modelContext.save()
            draft = newDraft
        } catch {
            // Slice 0: keep failure silent-but-safe; surfacing inline is a Slice 1 polish item.
        }
    }
}
