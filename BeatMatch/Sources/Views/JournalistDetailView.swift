import SwiftUI
import SwiftData

struct JournalistDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AIClient.self) private var aiClient
    @Environment(Entitlements.self) private var entitlements
    let target: MediaTarget
    let campaign: Campaign

    @State private var draft: PitchDraft?
    @State private var isDrafting = false
    @State private var draftError: String?

    private var draftingService: PitchDraftingService {
        DefaultPitchDraftingService(ai: aiClient)
    }

    private var journalist: JournalistProfile? { target.journalist }

    private var relevance: RelevanceResult? {
        guard let journalist, let story = campaign.story else { return nil }
        return RelevanceEngine.score(analysis: story.analysisResult, journalist: journalist)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header

                whyCard

                if let relevance {
                    scoreCard(relevance)
                }

                if let bylines = journalist?.recentBylineTitles, !bylines.isEmpty {
                    Card {
                        VStack(alignment: .leading, spacing: 10) {
                            SectionLabel(title: "Recent bylines")
                            ForEach(bylines, id: \.self) { title in
                                HStack(alignment: .top, spacing: 8) {
                                    Image(systemName: "text.append")
                                        .font(.caption)
                                        .foregroundStyle(Palette.accent)
                                        .padding(.top, 2)
                                    Text(title)
                                        .font(.subheadline)
                                        .foregroundStyle(Palette.ink)
                                }
                            }
                        }
                    }
                }

                if let journalist {
                    provenanceCard(journalist)
                }
            }
            .padding(Metrics.gutter)
            .padding(.bottom, 96)
        }
        .screenBackground()
        .navigationTitle("Match")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) { draftBar }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                Monogram(name: journalist?.name ?? "?", size: 56)
                VStack(alignment: .leading, spacing: 3) {
                    Text(journalist?.name ?? "Unknown")
                        .font(.title2.bold())
                        .foregroundStyle(Palette.ink)
                    if let outlet = journalist?.outlet?.name {
                        Text(outlet)
                            .font(.subheadline)
                            .foregroundStyle(Palette.inkSecondary)
                    }
                }
                Spacer(minLength: 0)
            }
            HStack(spacing: 8) {
                ConfidencePill(tier: target.confidenceTier)
                if journalist?.isSampleData == true {
                    Tag(text: "Sample data", icon: "flask", color: Palette.warning)
                } else if let c = journalist?.evidenceConfidence {
                    EvidenceDot(confidence: c)
                }
            }
        }
    }

    private var whyCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 8) {
                SectionLabel(title: "Why this match")
                Text(target.explanation?.reasonText ?? "—")
                    .font(.callout)
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @State private var showScore = false

    private func scoreCard(_ result: RelevanceResult) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                Button {
                    withAnimation(.snappy) { showScore.toggle() }
                } label: {
                    HStack {
                        SectionLabel(title: "How we scored this")
                        Image(systemName: showScore ? "chevron.up" : "chevron.down")
                            .font(.caption).foregroundStyle(Palette.inkTertiary)
                    }
                }
                .buttonStyle(.plain)

                ScoreBar(value: result.total)

                if showScore {
                    VStack(spacing: 8) {
                        ForEach(result.signals.sorted { $0.contribution > $1.contribution }) { s in
                            SignalRow(signal: s)
                        }
                    }
                    .padding(.top, 2)
                    Text("A weighted read of structured beat, coverage and preference data — no AI, no guesswork.")
                        .font(.caption2)
                        .foregroundStyle(Palette.inkTertiary)
                }
            }
        }
    }

    private func provenanceCard(_ journalist: JournalistProfile) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 14) {
                SectionLabel(title: "About this profile")

                ForEach(journalist.orderedProvenance) { record in
                    ProvenanceRow(record: record)
                }

                Divider().overlay(Palette.hairline)

                if journalist.hasReportedIssue {
                    Label("Reported — thanks, we'll review this.", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(Palette.evidence(.high))
                } else {
                    Button("Report an issue with this profile") {
                        Haptics.tap()
                        for record in journalist.provenanceRecords { record.issueReported = true }
                        try? modelContext.save()
                    }
                    .font(.footnote)
                    .foregroundStyle(Palette.inkSecondary)
                }
            }
        }
    }

    private var draftBar: some View {
        VStack(spacing: 8) {
            if let draftError {
                Text(draftError)
                    .font(.caption)
                    .foregroundStyle(Palette.warning)
                    .multilineTextAlignment(.center)
            }
            if let draft {
                NavigationLink { PitchDraftView(draft: draft) } label: {
                    Label("View draft", systemImage: "arrow.right")
                }
                .buttonStyle(.pitchwire)
            } else {
                Button {
                    Task { await generateDraft() }
                } label: {
                    if isDrafting {
                        HStack(spacing: 8) { ProgressView().tint(.white); Text("Writing…") }
                    } else {
                        Label("Draft pitch", systemImage: "square.and.pencil")
                    }
                }
                .buttonStyle(.pitchwire)
                .disabled(isDrafting)
            }
            AllowanceFooter(key: .aiPitchDraft)
        }
        .padding(Metrics.gutter)
        .background(.bar)
    }

    private func generateDraft() async {
        guard let journalist, let story = campaign.story else { return }

        draftError = nil
        guard entitlements.consume(.aiPitchDraft) else {
            Haptics.warning()
            draftError = "You've used all \(entitlements.plan.limit(for: .aiPitchDraft) ?? 0) AI pitch drafts on the \(entitlements.plan.tier.displayName) plan this period."
            return
        }

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
            Haptics.success()
            withAnimation(.snappy) { draft = newDraft }
        } catch {
            draftError = "Couldn't draft that pitch. Try again."
        }
    }
}

private struct ScoreBar: View {
    let value: Double   // 0...1
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Palette.hairline)
                Capsule().fill(Palette.accent)
                    .frame(width: max(6, geo.size.width * value))
            }
        }
        .frame(height: 8)
        .accessibilityLabel("Match score \(Int(value * 100)) out of 100")
    }
}

private struct SignalRow: View {
    let signal: RelevanceSignal
    var body: some View {
        HStack(spacing: 10) {
            Text(signal.name)
                .font(.caption)
                .foregroundStyle(Palette.inkSecondary)
                .frame(width: 108, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Palette.hairline).frame(height: 5)
                    Capsule()
                        .fill(signal.score >= 0.35 ? Palette.accent : Palette.inkTertiary)
                        .frame(width: max(3, geo.size.width * signal.score), height: 5)
                }
            }
            .frame(height: 5)
            Text("\(Int(signal.weight * 100))%")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(Palette.inkTertiary)
                .frame(width: 34, alignment: .trailing)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(signal.name): \(Int(signal.score * 100)) percent, weight \(Int(signal.weight * 100)) percent")
    }
}

private struct ProvenanceRow: View {
    let record: ProvenanceRecord

    private var tint: Color {
        switch record.sourceType {
        case .claimedProfile: return Palette.evidence(.high)
        case .publisherPartner: return Color(hex: 0x2563C9)
        case .licensedDataset: return Palette.warning
        case .publicSignal: return Palette.inkSecondary
        case .sampleData: return Palette.inkTertiary
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: record.sourceType.systemImage)
                .font(.footnote)
                .foregroundStyle(tint)
                .frame(width: 22, height: 22)
                .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 6, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(record.sourceType.label)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Palette.ink)
                Text(record.detail)
                    .font(.footnote)
                    .foregroundStyle(Palette.inkSecondary)
                if let basis = record.coverageBasis {
                    Text(basis).font(.caption).foregroundStyle(Palette.inkTertiary)
                }
                Text("Last verified \(record.lastVerifiedAt.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption)
                    .foregroundStyle(Palette.inkTertiary)
                if let pref = record.pitchPreference {
                    Text("Prefers: \(pref)")
                        .font(.caption)
                        .foregroundStyle(Palette.inkSecondary)
                        .padding(.top, 1)
                }
            }
        }
    }
}
