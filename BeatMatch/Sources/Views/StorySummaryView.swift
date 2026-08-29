import SwiftUI
import SwiftData

/// Screen 2 in the North Star flow: confirm the app understood the story before
/// spending the user's attention on a match list. Editable so a wrong tag doesn't
/// cascade into wrong recommendations.
struct StorySummaryView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var campaign: Campaign

    @State private var newSubtopic = ""
    @State private var showMatches = false

    private static let angles = ["product launch", "funding", "acquisition", "hire", "partnership", "general news"]
    private static let regions = ["US", "EU", "Global"]

    private var story: Story? { campaign.story }

    var body: some View {
        ScrollView {
            if let story {
                VStack(alignment: .leading, spacing: 16) {
                    Card {
                        VStack(alignment: .leading, spacing: 8) {
                            SectionLabel(title: "What we understood")
                            Text(story.summary ?? "")
                                .font(.callout)
                                .foregroundStyle(Palette.ink)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    Card {
                        VStack(alignment: .leading, spacing: 2) {
                            SummaryRow(label: "Theme", value: story.theme ?? "—")
                            Divider().overlay(Palette.hairline)
                            SummaryRow(label: "Audience", value: story.audience ?? "—")
                            Divider().overlay(Palette.hairline)
                            MenuRow(label: "Angle",
                                    selection: Binding(get: { story.angle ?? "general news" }, set: { story.angle = $0; Haptics.select() }),
                                    options: Self.angles, display: { $0.capitalized })
                            Divider().overlay(Palette.hairline)
                            MenuRow(label: "Region",
                                    selection: Binding(get: { story.region ?? "US" }, set: { story.region = $0; Haptics.select() }),
                                    options: Self.regions, display: { $0 })
                            Divider().overlay(Palette.hairline)
                            SummaryRow(label: "Timing",
                                       value: story.urgency == "time-sensitive" ? "Time-sensitive" : "Standard",
                                       valueColor: story.urgency == "time-sensitive" ? Palette.warning : Palette.inkSecondary)
                        }
                    }

                    Card {
                        VStack(alignment: .leading, spacing: 10) {
                            SectionLabel(title: "Topics")
                            Text("These drive who we match. Remove anything off, add what's missing.")
                                .font(.caption)
                                .foregroundStyle(Palette.inkTertiary)
                            ChipEditor(items: Binding(get: { story.subtopics }, set: { story.subtopics = $0 }),
                                       draft: $newSubtopic,
                                       placeholder: "Add a topic")
                        }
                    }

                    if !story.mediaHooks.isEmpty {
                        Card {
                            VStack(alignment: .leading, spacing: 10) {
                                SectionLabel(title: "Why a journalist would care")
                                ForEach(story.mediaHooks, id: \.self) { hook in
                                    HStack(alignment: .top, spacing: 8) {
                                        Image(systemName: "quote.opening")
                                            .font(.caption)
                                            .foregroundStyle(Palette.accent)
                                            .padding(.top, 2)
                                        Text(hook)
                                            .font(.subheadline)
                                            .foregroundStyle(Palette.ink)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(Metrics.gutter)
                .padding(.bottom, 88)
            } else {
                ContentUnavailableView("No story", systemImage: "doc.text")
            }
        }
        .screenBackground()
        .navigationTitle("Your story")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            Button {
                findJournalists()
            } label: {
                Label("Find journalists", systemImage: "magnifyingglass")
            }
            .buttonStyle(.pitchwire)
            .padding(Metrics.gutter)
            .background(.bar)
        }
        .navigationDestination(isPresented: $showMatches) {
            MatchListView(campaign: campaign)
        }
    }

    private func findJournalists() {
        Haptics.tap()
        try? modelContext.save()
        MatchRunner.populateTargets(for: campaign, context: modelContext)
        try? modelContext.save()
        showMatches = true
    }
}

private struct SummaryRow: View {
    let label: String
    let value: String
    var valueColor: Color = Palette.inkSecondary

    var body: some View {
        HStack {
            Text(label).font(.subheadline).foregroundStyle(Palette.ink)
            Spacer()
            Text(value).font(.subheadline).foregroundStyle(valueColor)
        }
        .padding(.vertical, 10)
    }
}

private struct MenuRow: View {
    let label: String
    @Binding var selection: String
    let options: [String]
    let display: (String) -> String

    var body: some View {
        Menu {
            Picker(label, selection: $selection) {
                ForEach(options, id: \.self) { Text(display($0)).tag($0) }
            }
        } label: {
            HStack {
                Text(label).font(.subheadline).foregroundStyle(Palette.ink)
                Spacer()
                Text(display(selection)).font(.subheadline).foregroundStyle(Palette.accent)
                Image(systemName: "chevron.up.chevron.down").font(.caption2).foregroundStyle(Palette.inkTertiary)
            }
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
    }
}

/// Removable capsules + an inline add field.
private struct ChipEditor: View {
    @Binding var items: [String]
    @Binding var draft: String
    let placeholder: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !items.isEmpty {
                FlowLayout(spacing: 8) {
                    ForEach(items, id: \.self) { item in
                        HStack(spacing: 4) {
                            Text(item)
                            Button {
                                Haptics.tap()
                                items.removeAll { $0 == item }
                            } label: {
                                Image(systemName: "xmark")
                            }
                            .buttonStyle(.plain)
                        }
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Palette.accent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Palette.accentSoft, in: Capsule())
                    }
                }
            }
            HStack {
                TextField(placeholder, text: $draft)
                    .textInputAutocapitalization(.never)
                    .onSubmit(add)
                Button("Add", action: add)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Palette.accent)
                    .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    private func add() {
        let value = draft.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !value.isEmpty, !items.contains(value) else { return }
        Haptics.tap()
        items.append(value)
        draft = ""
    }
}

/// Minimal wrapping HStack for the chips.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > maxWidth {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: maxWidth == .infinity ? x : maxWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
