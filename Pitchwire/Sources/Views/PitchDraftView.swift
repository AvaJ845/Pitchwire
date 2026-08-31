import SwiftUI
import SwiftData

struct PitchDraftView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AIClient.self) private var aiClient
    @Bindable var draft: PitchDraft
    @State private var length: Length = .short
    @State private var copied = false
    @State private var offerFollowUp = false
    @State private var polishing = false

    private var draftingService: PitchDraftingService { DefaultPitchDraftingService(ai: aiClient) }

    enum Length: String, CaseIterable { case short = "Short", long = "Long" }

    private var activeBody: Binding<String> {
        length == .short ? $draft.shortBody : $draft.longBody
    }

    private var sent: Bool { draft.status == .markedSent }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Card {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            SectionLabel(title: "Subject")
                            Spacer()
                            if polishing {
                                Label("Polishing…", systemImage: "sparkles")
                                    .font(.caption2.weight(.medium))
                                    .foregroundStyle(Palette.inkTertiary)
                            } else if draft.aiEnhanced {
                                Label("AI", systemImage: "sparkles")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(Palette.accent)
                            }
                        }
                        TextField("Subject", text: $draft.subject, axis: .vertical)
                            .font(.headline)
                            .foregroundStyle(Palette.ink)
                    }
                }

                Picker("Length", selection: $length) {
                    ForEach(Length.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)

                Card {
                    VStack(alignment: .leading, spacing: 8) {
                        SectionLabel(title: "\(length.rawValue) pitch")
                        TextEditor(text: activeBody)
                            .font(.callout)
                            .foregroundStyle(Palette.ink)
                            .frame(minHeight: length == .short ? 220 : 320)
                            .scrollContentBackground(.hidden)
                            .accessibilityLabel("\(length.rawValue) pitch body")
                    }
                }

                HStack(spacing: 10) {
                    Button {
                        UIPasteboard.general.string = "\(draft.subject)\n\n\(activeBody.wrappedValue)"
                        Haptics.success()
                        withAnimation { copied = true }
                        UIAccessibility.post(notification: .announcement, argument: "Copied to clipboard")
                        Task {
                            try? await Task.sleep(for: .seconds(1.6))
                            withAnimation { copied = false }
                        }
                    } label: {
                        Label(copied ? "Copied" : "Copy", systemImage: copied ? "checkmark" : "doc.on.doc")
                    }
                    .buttonStyle(.pitchwireQuiet)
                    .accessibilityLabel("Copy subject and pitch")

                    ShareLink(item: "\(draft.subject)\n\n\(activeBody.wrappedValue)") {
                        Label("Share", systemImage: "square.and.arrow.up")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .foregroundStyle(Palette.accent)
                            .background(Palette.accentSoft, in: RoundedRectangle(cornerRadius: Metrics.controlRadius, style: .continuous))
                    }
                }

                Button {
                    Haptics.success()
                    let wasSent = sent
                    withAnimation(.snappy) { draft.status = wasSent ? .draft : .markedSent }
                    try? modelContext.save()
                    if !wasSent, draft.campaign != nil,
                       !(draft.campaign?.followUpTasks.contains { $0.title.contains(recipientName) } ?? false) {
                        offerFollowUp = true
                    }
                } label: {
                    Label(sent ? "Marked as sent" : "Mark as sent",
                          systemImage: sent ? "checkmark.circle.fill" : "circle")
                        .font(.subheadline.weight(.medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .foregroundStyle(sent ? .white : Palette.ink)
                        .background(
                            sent ? Palette.evidence(.high) : Palette.surface,
                            in: RoundedRectangle(cornerRadius: Metrics.controlRadius, style: .continuous)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: Metrics.controlRadius, style: .continuous)
                                .strokeBorder(Palette.hairline, lineWidth: sent ? 0 : 1)
                        )
                }
                .accessibilityLabel("Mark as sent")
                .accessibilityValue(sent ? "Sent" : "Not sent")
                .accessibilityAddTraits(sent ? .isSelected : [])
            }
            .padding(Metrics.gutter)
        }
        .screenBackground()
        .navigationTitle("Pitch draft")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Sent to \(recipientName)", isPresented: $offerFollowUp, titleVisibility: .visible) {
            Button("Remind me in 3 days") { addFollowUp(days: 3) }
            Button("Remind me in a week") { addFollowUp(days: 7) }
            Button("No reminder", role: .cancel) {}
        } message: {
            Text("Add a follow-up so this doesn't go quiet.")
        }
        .task(id: draft.id) { await polishIfNeeded() }
    }

    /// The grounded template is already on screen. If a backend is configured and
    /// this draft hasn't been rewritten yet, ask the model — in place, no blocking.
    private func polishIfNeeded() async {
        guard !draft.aiEnhanced, aiClient.isConfigured,
              let story = draft.campaign?.story else { return }
        let analysis = story.analysisResult
        let rawText = story.rawText
        let name = recipientName
        let matchReason = draft.mediaTarget?.explanation?.reasonText ?? ""

        polishing = true
        defer { polishing = false }
        guard let polished = await draftingService.polish(
            story: analysis, rawText: rawText, recipientName: name, matchReason: matchReason)
        else { return }
        withAnimation(.snappy) {
            draft.apply(polished)
            draft.aiEnhanced = true
        }
        try? modelContext.save()
    }

    private var recipientName: String {
        draft.mediaTarget?.journalist?.name ?? "this journalist"
    }

    private func addFollowUp(days: Int) {
        guard let campaign = draft.campaign else { return }
        Haptics.tap()
        let task = FollowUpTask(
            title: "Follow up with \(recipientName)",
            dueDate: .now.addingTimeInterval(Double(days) * 86_400),
            campaign: campaign
        )
        modelContext.insert(task)
        campaign.followUpTasks.append(task)
        try? modelContext.save()
    }
}
