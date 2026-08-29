import SwiftUI

struct PitchDraftView: View {
    @Bindable var draft: PitchDraft
    @State private var length: Length = .short
    @State private var copied = false

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
                        SectionLabel(title: "Subject")
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
                    }
                }

                HStack(spacing: 10) {
                    Button {
                        UIPasteboard.general.string = "\(draft.subject)\n\n\(activeBody.wrappedValue)"
                        Haptics.success()
                        withAnimation { copied = true }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { withAnimation { copied = false } }
                    } label: {
                        Label(copied ? "Copied" : "Copy", systemImage: copied ? "checkmark" : "doc.on.doc")
                    }
                    .buttonStyle(.pitchwireQuiet)

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
                    withAnimation(.snappy) { draft.status = sent ? .draft : .markedSent }
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
                .accessibilityLabel("Marked as sent")
                .accessibilityValue(sent ? "on" : "off")
            }
            .padding(Metrics.gutter)
        }
        .screenBackground()
        .navigationTitle("Pitch draft")
        .navigationBarTitleDisplayMode(.inline)
    }
}
