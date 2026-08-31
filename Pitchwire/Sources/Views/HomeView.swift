import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AIClient.self) private var aiClient
    @Environment(Entitlements.self) private var entitlements
    @Environment(\.scenePhase) private var scenePhase

    @Query(sort: \Campaign.createdAt, order: .reverse) private var campaigns: [Campaign]

    @State private var storyText: String = ""
    @State private var isAnalyzing = false
    @State private var activeCampaign: Campaign?
    @State private var errorMessage: String?
    @FocusState private var editorFocused: Bool

    private var analysisService: StoryAnalysisService {
        DefaultStoryAnalysisService(ai: aiClient)
    }

    private var canAnalyze: Bool {
        !storyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isAnalyzing
    }

    private static let examples = [
        "We raised a $2M seed round to build an AI coding assistant for small teams.",
        "Today we're launching a privacy-first note app that runs entirely on device.",
        "Our open-source API framework hit 10,000 GitHub stars this week."
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header

                    storyInput

                    if let errorMessage {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote)
                            .foregroundStyle(Palette.warning)
                    }

                    Button {
                        Task { await analyze() }
                    } label: {
                        HStack(spacing: 8) {
                            if isAnalyzing {
                                ProgressView().tint(.white)
                                Text("Reading your story…")
                            } else {
                                Image(systemName: "sparkles")
                                Text("Analyze")
                            }
                        }
                    }
                    .buttonStyle(.pitchwire)
                    .disabled(!canAnalyze)

                    AllowanceFooter(key: .storyAnalysis)

                    Label("Our directory is deepest in AI & developer tools and privacy & security, "
                          + "with lighter coverage of fintech and consumer apps. Stories outside "
                          + "those areas may not match well yet.",
                          systemImage: "text.magnifyingglass")
                        .font(.caption)
                        .foregroundStyle(Palette.inkSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)

                    if !dueFollowUps.isEmpty {
                        dueSection
                    }

                    if storyText.isEmpty {
                        examplesSection
                    }

                    if !campaigns.isEmpty {
                        recentSection
                    }
                }
                .padding(Metrics.gutter)
                .readableWidth()
            }
            .scrollDismissesKeyboard(.interactively)
            .screenBackground()
            .navigationTitle("Pitchwire")
            .navigationDestination(item: $activeCampaign) { campaign in
                StorySummaryView(campaign: campaign)
            }
            .task { pickUpPendingStory() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { pickUpPendingStory() }
            }
        }
    }

    /// Runs on appear and every time the app returns to foreground.
    /// - A story shared in via the Share Extension takes precedence.
    /// - Otherwise, "Get started" from onboarding seeds the first example.
    private func pickUpPendingStory() {
        if let shared = SharedInbox.take(), storyText.isEmpty {
            storyText = shared
            editorFocused = true
            return
        }
        if UserDefaults.standard.bool(forKey: "pitchwire.seedExampleOnce") {
            UserDefaults.standard.removeObject(forKey: "pitchwire.seedExampleOnce")
            if storyText.isEmpty, let first = Self.examples.first {
                storyText = first
                editorFocused = true
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("What's your story?")
                .font(.largeTitle.bold())
                .foregroundStyle(Palette.ink)
            Text("Paste a launch story, press release, or announcement. We'll tell you who's most likely to care, why, and what to say.")
                .font(.subheadline)
                .foregroundStyle(Palette.inkSecondary)
        }
    }

    private var storyInput: some View {
        Card(padding: 4) {
            ZStack(alignment: .topLeading) {
                if storyText.isEmpty {
                    Text("Paste your story here…")
                        .foregroundStyle(Palette.inkTertiary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 14)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $storyText)
                    .focused($editorFocused)
                    .frame(minHeight: 200)
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .accessibilityLabel("Your story")
                    .accessibilityHint("Paste a launch story, press release, or announcement")
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if !storyText.isEmpty {
                Text("\(storyText.count)")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(Palette.inkTertiary)
                    .padding(10)
                    .accessibilityLabel("\(storyText.count) characters")
            }
        }
    }

    private var examplesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(title: "Try one")
            ForEach(Self.examples, id: \.self) { example in
                Button {
                    Haptics.tap()
                    storyText = example
                    editorFocused = true
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "text.quote")
                            .foregroundStyle(Palette.accent)
                        Text(example)
                            .font(.footnote)
                            .foregroundStyle(Palette.inkSecondary)
                            .multilineTextAlignment(.leading)
                        Spacer(minLength: 0)
                    }
                }
                .buttonStyle(.plain)
                .padding(12)
                .background(Palette.surface, in: RoundedRectangle(cornerRadius: Metrics.controlRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Metrics.controlRadius, style: .continuous)
                        .strokeBorder(Palette.hairline, lineWidth: 1)
                )
            }
        }
    }

    private var dueFollowUps: [FollowUpTask] {
        campaigns
            .flatMap(\.followUpTasks)
            .filter { !$0.isDone && ($0.dueDate.map { $0 < .now.addingTimeInterval(86_400) } ?? false) }
            .sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
    }

    private var dueSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(title: "Follow-ups due")
            ForEach(dueFollowUps.prefix(3)) { task in
                NavigationLink {
                    if let c = task.campaign { FollowUpsView(campaign: c) }
                } label: {
                    Card {
                        HStack(spacing: 10) {
                            Image(systemName: "bell.badge")
                                .foregroundStyle(Palette.warning)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(task.title).font(.subheadline).foregroundStyle(Palette.ink)
                                if let c = task.campaign {
                                    Text(c.name).font(.caption).foregroundStyle(Palette.inkTertiary)
                                }
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right").font(.caption).foregroundStyle(Palette.inkTertiary)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(title: "Recent")
            ForEach(campaigns.prefix(3)) { campaign in
                NavigationLink {
                    MatchListView(campaign: campaign)
                } label: {
                    CampaignRow(campaign: campaign)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func analyze() async {
        errorMessage = nil
        editorFocused = false

        guard entitlements.consume(.storyAnalysis) else {
            Haptics.warning()
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

            Haptics.success()
            storyText = ""
            activeCampaign = campaign
        } catch {
            Haptics.warning()
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
        Group {
            if entitlements.isUnlimited(key) {
                Text("\(key.displayName): unlimited on \(entitlements.plan.tier.displayName)")
            } else if let remaining = entitlements.remaining(key) {
                let limit = entitlements.plan.limit(for: key) ?? 0
                Text("\(remaining) of \(limit) \(key.displayName) left this period")
                    .foregroundStyle(remaining == 0 ? Palette.warning : Palette.inkTertiary)
            }
        }
        .font(.caption)
        .foregroundStyle(Palette.inkTertiary)
        .frame(maxWidth: .infinity)
    }
}
