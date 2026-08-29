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
        Form {
            if let story {
                Section {
                    Text(story.summary ?? "")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("What we understood")
                }

                Section("The story") {
                    LabeledContent("Theme", value: story.theme ?? "—")
                    LabeledContent("Audience", value: story.audience ?? "—")
                    Picker("Angle", selection: Binding(
                        get: { story.angle ?? "general news" },
                        set: { story.angle = $0 }
                    )) {
                        ForEach(Self.angles, id: \.self) { Text($0.capitalized).tag($0) }
                    }
                    Picker("Region", selection: Binding(
                        get: { story.region ?? "US" },
                        set: { story.region = $0 }
                    )) {
                        ForEach(Self.regions, id: \.self) { Text($0).tag($0) }
                    }
                    LabeledContent("Timing") {
                        Text(story.urgency == "time-sensitive" ? "Time-sensitive" : "Standard")
                            .foregroundStyle(story.urgency == "time-sensitive" ? .orange : .secondary)
                    }
                }

                Section {
                    ChipEditor(items: Binding(get: { story.subtopics }, set: { story.subtopics = $0 }),
                               draft: $newSubtopic,
                               placeholder: "Add a topic")
                } header: {
                    Text("Topics")
                } footer: {
                    Text("These drive who we match. Remove anything off, add what's missing.")
                }

                if !story.mediaHooks.isEmpty {
                    Section("Why a journalist would care") {
                        ForEach(story.mediaHooks, id: \.self) { hook in
                            Label(hook, systemImage: "quote.opening")
                                .labelStyle(.titleAndIcon)
                        }
                    }
                }
            } else {
                ContentUnavailableView("No story", systemImage: "doc.text")
            }
        }
        .navigationTitle("Your story")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            Button {
                findJournalists()
            } label: {
                Text("Find journalists")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding()
            .background(.bar)
        }
        .navigationDestination(isPresented: $showMatches) {
            MatchListView(campaign: campaign)
        }
    }

    private func findJournalists() {
        try? modelContext.save()
        MatchRunner.populateTargets(for: campaign, context: modelContext)
        try? modelContext.save()
        showMatches = true
    }
}

/// Removable capsules + an inline add field.
private struct ChipEditor: View {
    @Binding var items: [String]
    @Binding var draft: String
    let placeholder: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !items.isEmpty {
                FlowLayout(spacing: 8) {
                    ForEach(items, id: \.self) { item in
                        HStack(spacing: 4) {
                            Text(item)
                            Button {
                                items.removeAll { $0 == item }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.secondary)
                        }
                        .font(.footnote)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Color(.tertiarySystemFill)))
                    }
                }
            }
            HStack {
                TextField(placeholder, text: $draft)
                    .textInputAutocapitalization(.never)
                    .onSubmit(add)
                Button("Add", action: add)
                    .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(.vertical, 4)
    }

    private func add() {
        let value = draft.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !value.isEmpty, !items.contains(value) else { return }
        items.append(value)
        draft = ""
    }
}

/// Minimal wrapping HStack for the chips.
private struct FlowLayout: Layout {
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
