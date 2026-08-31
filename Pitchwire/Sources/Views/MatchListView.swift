import SwiftUI
import SwiftData

struct MatchListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AIClient.self) private var aiClient
    let campaign: Campaign

    @State private var enriching = false

    private var visibleTargets: [MediaTarget] {
        campaign.mediaTargets.filter { $0.status != .hidden }
    }

    private var grouped: [(ConfidenceTier, [MediaTarget])] {
        let tiers: [ConfidenceTier] = [.excellent, .strong, .possible]
        return tiers.compactMap { tier in
            let matches = visibleTargets
                .filter { $0.confidenceTier == tier }
                .sorted { $0.confidenceScore > $1.confidenceScore }
            return matches.isEmpty ? nil : (tier, matches)
        }
    }

    private var hiddenCount: Int { campaign.mediaTargets.filter { $0.status == .hidden }.count }

    /// The least-verified state present — drives the honesty banner.
    private var evidenceState: ProfileEvidenceState? {
        let states = visibleTargets.compactMap { $0.journalist?.evidenceState }
        if states.contains(.demo) { return .demo }
        if states.contains(.candidate) { return .candidate }
        return nil   // all verified — no banner needed
    }

    var body: some View {
        List {
            if let story = campaign.story {
                Section {
                    ZStack {
                        NavigationLink { StorySummaryView(campaign: campaign) } label: { EmptyView() }.opacity(0)
                        StorySummaryCard(story: story, matchCount: visibleTargets.count)
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: Metrics.gutter, bottom: 4, trailing: Metrics.gutter))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
            }

            if let evidenceState {
                Section {
                    EvidenceNoticeBanner(state: evidenceState)
                        .listRowInsets(EdgeInsets(top: 4, leading: Metrics.gutter, bottom: 8, trailing: Metrics.gutter))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
            }

            ForEach(grouped, id: \.0) { tier, targets in
                Section {
                    ForEach(targets) { target in
                        ZStack {
                            NavigationLink {
                                JournalistDetailView(target: target, campaign: campaign)
                            } label: { EmptyView() }.opacity(0)
                            MatchRow(target: target)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityAddTraits(.isButton)
                        .listRowInsets(EdgeInsets(top: 5, leading: Metrics.gutter, bottom: 5, trailing: Metrics.gutter))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .swipeActions(edge: .leading) {
                            Button {
                                setStatus(target, target.status == .shortlisted ? .suggested : .shortlisted)
                            } label: {
                                Label(target.status == .shortlisted ? "Unstar" : "Shortlist",
                                      systemImage: target.status == .shortlisted ? "star.slash" : "star")
                            }
                            .tint(Palette.accent)
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                setStatus(target, .hidden)
                            } label: { Label("Hide", systemImage: "eye.slash") }
                        }
                        .overlay(alignment: .topLeading) {
                            if target.status == .shortlisted {
                                Image(systemName: "star.fill")
                                    .font(.caption2)
                                    .foregroundStyle(Palette.accent)
                                    .padding(6)
                            }
                        }
                    }
                } header: {
                    TierHeader(tier: tier, count: targets.count)
                }
            }

            if hiddenCount > 0 {
                Section {
                    Button("Show \(hiddenCount) hidden") { unhideAll() }
                        .font(.footnote)
                        .foregroundStyle(Palette.accent)
                        .listRowBackground(Color.clear)
                }
            }

            if grouped.isEmpty && hiddenCount == 0 {
                ContentUnavailableView {
                    Label("No matches yet", systemImage: "person.crop.circle.badge.questionmark")
                } description: {
                    Text("This story didn't overlap with anyone in the pool. Try editing the topics.")
                }
                .listRowBackground(Color.clear)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .screenBackground()
        .navigationTitle(campaign.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    FollowUpsView(campaign: campaign)
                } label: {
                    Label("Follow-ups", systemImage: openFollowUps > 0 ? "bell.badge" : "bell")
                }
            }
        }
        .task(id: campaign.id) {
            guard !enriching else { return }
            enriching = true
            await ExplanationEnricher.enrich(campaign: campaign, using: aiClient, context: modelContext)
            enriching = false
        }
    }

    private var openFollowUps: Int {
        campaign.followUpTasks.filter { !$0.isDone }.count
    }

    private func setStatus(_ target: MediaTarget, _ status: MediaTargetStatus) {
        Haptics.select()
        withAnimation(.snappy) { target.status = status }
        try? modelContext.save()
    }

    private func unhideAll() {
        withAnimation(.snappy) {
            campaign.mediaTargets.filter { $0.status == .hidden }.forEach { $0.status = .suggested }
        }
        try? modelContext.save()
    }
}

private struct TierHeader: View {
    let tier: ConfidenceTier
    let count: Int

    var body: some View {
        HStack(spacing: 8) {
            Circle().fill(Palette.tier(tier)).frame(width: 8, height: 8)
            Text(tier.displayName)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Palette.ink)
            Text("\(count)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Palette.inkTertiary)
            Spacer()
        }
        .textCase(nil)
        .padding(.top, 4)
    }
}

struct StorySummaryCard: View {
    let story: Story
    let matchCount: Int

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    SectionLabel(title: story.theme ?? "Story")
                    Image(systemName: "pencil")
                        .font(.caption)
                        .foregroundStyle(Palette.accent)
                }
                Text(story.summary ?? "")
                    .font(.subheadline)
                    .foregroundStyle(Palette.inkSecondary)
                    .lineLimit(3)
                HStack(spacing: 6) {
                    if matchCount > 0 { Tag(text: "\(matchCount) matches", icon: "person.2", color: Palette.accent) }
                    if let region = story.region { Tag(text: region, color: Palette.inkSecondary) }
                    if story.urgency == "time-sensitive" { Tag(text: "Time-sensitive", icon: "clock", color: Palette.warning) }
                }
            }
        }
    }
}
