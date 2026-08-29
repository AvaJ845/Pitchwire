import SwiftUI

struct PitchDraftView: View {
    @Bindable var draft: PitchDraft

    var body: some View {
        Form {
            Section("Subject") {
                TextField("Subject", text: $draft.subject)
            }
            Section("Short pitch") {
                TextEditor(text: $draft.shortBody)
                    .frame(minHeight: 140)
            }
            Section("Long pitch") {
                TextEditor(text: $draft.longBody)
                    .frame(minHeight: 220)
            }
            Section {
                Toggle("Marked as sent", isOn: Binding(
                    get: { draft.status == .markedSent },
                    set: { draft.status = $0 ? .markedSent : .draft }
                ))
            }
        }
        .navigationTitle("Pitch draft")
        .navigationBarTitleDisplayMode(.inline)
    }
}
