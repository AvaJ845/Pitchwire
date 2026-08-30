import SwiftUI
import SwiftData

struct JournalistDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AIClient.self) private var aiClient
    @Environment(Entitlements.self) private var entitlements
    let target: MediaTarget
    let campaign: Campaign

    @State private var draft: PitchDraft?
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

                if let journalist, !journalist.beatTopics.isEmpty {
                    coversCard(journalist)
                }

                whyCard

                if let relevance {
                    scoreCard(relevance)
                }

                if let journalist {
                    evidenceCard(journalist)
                    sourcesCard(journalist)
                }
            }
            .padding(Metrics.gutter)
            .padding(.bottom, 96)
        }
        .screenBackground()
        .navigationTitle("Match")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) { draftBar }
        .task(id: target.id) {
            // Enrich the reason for the card the user actually opened (if the
            // list didn't warm it). Background priority — yields to a pitch draft.
            guard let story = campaign.story else { return }
            await ExplanationEnricher.enrichOne(
                target: target, analysis: story.analysisResult,
                using: aiClient, context: modelContext)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                Monogram(name: journalist?.name ?? "?", size: 56)
                VStack(alignment: .leading, spacing: 3) {
                    // WHO
                    Text(journalist?.name ?? "Unknown")
                        .font(.title2.bold())
                        .foregroundStyle(Palette.ink)
                    if let role = journalist?.role {
                        Text(role)
                            .font(.caption)
                            .foregroundStyle(Palette.inkTertiary)
                    }
                    // WHERE THEY PUBLISH
                    outletLine
                }
                Spacer(minLength: 0)
            }
            HStack(spacing: 8) {
                ConfidencePill(tier: target.confidenceTier)
                if let state = journalist?.evidenceState {
                    Tag(text: state.tagText, icon: state.tagIcon, color: state.tagColor)
                }
                // CONFIDENCE
                if let c = journalist?.evidenceConfidence {
                    EvidenceDot(confidence: c)
                }
            }
        }
    }

    @ViewBuilder private var outletLine: some View {
        if let outlet = journalist?.outlet {
            if let urlString = outlet.url, let url = URL(string: urlString), !urlString.isEmpty {
                Link(destination: url) {
                    HStack(spacing: 4) {
                        Text(outlet.name)
                        Image(systemName: "arrow.up.right").font(.caption2)
                    }
                    .font(.subheadline)
                    .foregroundStyle(Palette.accent)
                }
            } else {
                Text(outlet.name)
                    .font(.subheadline)
                    .foregroundStyle(Palette.inkSecondary)
            }
        }
    }

    // WHAT THEY COVER
    private func coversCard(_ journalist: JournalistProfile) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 8) {
                SectionLabel(title: "Covers")
                FlowLayout(spacing: 6) {
                    ForEach(journalist.beatTopics, id: \.self) { topic in
                        Tag(text: topic, color: Palette.inkSecondary)
                    }
                }
            }
        }
    }

    private var whyCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    SectionLabel(title: "Why this match")
                    if target.explanation?.aiEnhanced == true {
                        Label("AI", systemImage: "sparkles")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Palette.accent)
                    }
                }
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
                    Text(result.relevanceDisclaimer)
                        .font(.caption2)
                        .foregroundStyle(Palette.inkTertiary)
                    Text("A weighted read of structured beat, coverage and preference data — no AI, no guesswork.")
                        .font(.caption2)
                        .foregroundStyle(Palette.inkTertiary)
                }
            }
        }
    }

    // EVIDENCE + SOURCE + VERIFICATION DATE
    private func evidenceCard(_ journalist: JournalistProfile) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    SectionLabel(title: "Evidence")
                    Spacer()
                    VerificationBadge(state: journalist.evidenceState, date: journalist.verificationDate)
                }

                let coverage = journalist.allCoverage
                if coverage.isEmpty {
                    Text("No article-level evidence recorded yet.")
                        .font(.footnote)
                        .foregroundStyle(Palette.inkTertiary)
                } else {
                    ForEach(coverage) { article in
                        EvidenceLinkRow(
                            title: article.title,
                            dateLabel: article.publishedLabel,
                            url: article.url
                        )
                    }
                }

                if let record = journalist.primaryEvidence {
                    Divider().overlay(Palette.hairline)
                    Text(record.evidenceSummary)
                        .font(.caption)
                        .foregroundStyle(Palette.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    if let src = record.sourceURL, let url = URL(string: src), !src.isEmpty {
                        Link(destination: url) {
                            Label("View source: \(url.host()?.replacingOccurrences(of: "www.", with: "") ?? src)",
                                  systemImage: "link")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(Palette.accent)
                        }
                    }
                }
            }
        }
    }

    // Provenance detail + report
    private func sourcesCard(_ journalist: JournalistProfile) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 14) {
                SectionLabel(title: "About this profile")

                ForEach(journalist.orderedEvidence) { record in
                    EvidenceRow(record: record)
                }

                Divider().overlay(Palette.hairline)

                if journalist.hasReportedIssue {
                    Label("Reported — thanks, we'll review this.", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(Palette.evidence(.high))
                } else {
                    Button("Report an issue with this profile") {
                        Haptics.tap()
                        for record in journalist.evidenceRecords { record.issueReported = true }
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
                    generateDraft()
                } label: {
                    Label("Draft pitch", systemImage: "square.and.pencil")
                }
                .buttonStyle(.pitchwire)
            }
            AllowanceFooter(key: .aiPitchDraft)
        }
        .padding(Metrics.gutter)
        .background(.bar)
    }

    private func generateDraft() {
        guard let journalist, let story = campaign.story else { return }

        draftError = nil
        guard entitlements.consume(.aiPitchDraft) else {
            Haptics.warning()
            draftError = "You've used all \(entitlements.plan.limit(for: .aiPitchDraft) ?? 0) AI pitch drafts on the \(entitlements.plan.tier.displayName) plan this period."
            return
        }

        // Read every @Model field on the main actor.
        let analysis = story.analysisResult
        let rawText = story.rawText
        let recipientName = journalist.name
        let matchReason = target.explanation?.reasonText ?? ""

        // Instant: build the grounded template and navigate straight to it.
        // PitchDraftView polishes it in place — no spinner here.
        let content = draftingService.template(
            story: analysis, rawText: rawText,
            recipientName: recipientName, matchReason: matchReason)
        let newDraft = PitchDraft(content: content, mediaTarget: target)
        newDraft.campaign = campaign
        modelContext.insert(newDraft)
        campaign.pitchDrafts.append(newDraft)
        try? modelContext.save()
        Haptics.success()
        withAnimation(.snappy) { draft = newDraft }
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

private struct EvidenceRow: View {
    let record: EditorialEvidenceRecord

    private var tint: Color {
        switch record.provenance {
        case .claimedProfile:        return Palette.evidence(.high)
        case .publisherProvided:     return Color(hex: 0x2563C9)
        case .licensedSource:        return Palette.warning
        case .publicEditorialSignal: return Palette.inkSecondary
        case .userProvided:          return Palette.accent
        case .fictionalSample:       return Palette.inkTertiary
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: record.provenance.systemImage)
                .font(.footnote)
                .foregroundStyle(tint)
                .frame(width: 22, height: 22)
                .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 6, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(record.provenance.label)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Palette.ink)
                Text(record.evidenceSummary)
                    .font(.footnote)
                    .foregroundStyle(Palette.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                if let verifiedAt = record.verificationDate {
                    Text("Verified \(verifiedAt.formatted(date: .abbreviated, time: .omitted))"
                         + (record.verifiedBy.map { " · \($0)" } ?? ""))
                        .font(.caption)
                        .foregroundStyle(Palette.inkTertiary)
                } else {
                    Text("Not yet verified")
                        .font(.caption)
                        .foregroundStyle(Palette.inkTertiary)
                }
                if let pref = record.pitchPreference {
                    Text("Published pitch note: \(pref)")
                        .font(.caption)
                        .foregroundStyle(Palette.inkSecondary)
                        .padding(.top, 1)
                }
            }
        }
    }
}
