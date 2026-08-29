import SwiftUI
import SwiftData

struct JournalistDetailView: View {
    @Environment(\.modelContext) private var modelContext
    let target: MediaTarget
    let campaign: Campaign

    @State private var draft: PitchDraft?
    @State private var isDrafting = false

    private let draftingService: PitchDraftingService = TemplatePitchDraftingService()

    private var journalist: JournalistProfile? { target.journalist }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(journalist?.name ?? "Unknown")
                        .font(.title.bold())
                    if let outlet = journalist?.outlet?.name {
                        Text(outlet)
                            .foregroundStyle(.secondary)
                    }
                    if let journalist {
                        ConfidenceBadge(confidence: journalist.evidenceConfidence)
                    }
                }

                if let reason = target.explanation?.reasonText {
                    GroupBox {
                        Text(reason)
                    } label: {
                        Text("Why this match")
                    }
                }

                if let bylines = journalist?.recentBylineTitles, !bylines.isEmpty {
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

                if let journalist {
                    GroupBox {
                        VStack(alignment: .leading, spacing: 14) {
                            ForEach(journalist.orderedProvenance) { record in
                                ProvenanceRow(record: record)
                            }

                            Divider()

                            if journalist.hasReportedIssue {
                                Label("Reported — thanks, we'll review this.", systemImage: "checkmark.circle")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else {
                                Button("Report an issue with this profile", role: .destructive) {
                                    for record in journalist.provenanceRecords { record.issueReported = true }
                                    try? modelContext.save()
                                }
                                .font(.footnote)
                            }
                        }
                    } label: {
                        Text("About this profile")
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
        guard let journalist, let story = campaign.story else { return }
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
            // Keep failure silent-but-safe; inline surfacing is a later polish item.
        }
    }
}

private struct ConfidenceBadge: View {
    let confidence: EvidenceConfidence

    private var color: Color {
        switch confidence {
        case .high: return .green
        case .moderate: return .orange
        case .exploratory: return .secondary
        }
    }

    var body: some View {
        Label(confidence.label, systemImage: "gauge.medium")
            .font(.caption.weight(.medium))
            .foregroundStyle(color)
            .padding(.top, 2)
    }
}

private struct ProvenanceRow: View {
    let record: ProvenanceRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Label(record.sourceType.label, systemImage: record.sourceType.systemImage)
                .font(.subheadline.weight(.medium))
            Text(record.detail)
                .font(.footnote)
                .foregroundStyle(.secondary)
            if let basis = record.coverageBasis {
                Text(basis)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text("Last verified \(record.lastVerifiedAt.formatted(date: .abbreviated, time: .omitted))")
                .font(.caption)
                .foregroundStyle(.secondary)
            if let pref = record.pitchPreference {
                Text("Pitch preference: \(pref)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
