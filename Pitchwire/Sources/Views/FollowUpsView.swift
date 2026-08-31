import SwiftUI
import SwiftData

/// Campaign memory: the follow-ups you owe on a campaign. Create, check off,
/// re-date, delete. This is the retention spine — keep it lightweight.
struct FollowUpsView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var campaign: Campaign

    @State private var newTitle = ""
    @State private var newDue: Date = .now.addingTimeInterval(3 * 86_400)
    @FocusState private var addingFocused: Bool

    private var open: [FollowUpTask] {
        campaign.followUpTasks.filter { !$0.isDone }
            .sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
    }
    private var done: [FollowUpTask] {
        campaign.followUpTasks.filter(\.isDone).sorted { $0.title < $1.title }
    }

    var body: some View {
        List {
            Section {
                TextField("e.g. Nudge Dana with the demo link", text: $newTitle, axis: .vertical)
                    .focused($addingFocused)
                DatePicker("Due", selection: $newDue, in: Date()..., displayedComponents: .date)
                Button {
                    addTask()
                } label: {
                    Label("Add", systemImage: "plus")
                }
                .disabled(newTitle.trimmingCharacters(in: .whitespaces).isEmpty)
            } header: {
                SectionLabel(title: "Add a follow-up")
            }

            if !open.isEmpty {
                Section {
                    ForEach(open) { row($0) }
                } header: {
                    SectionLabel(title: "Open")
                }
            }
            if !done.isEmpty {
                Section {
                    ForEach(done) { row($0) }
                } header: {
                    SectionLabel(title: "Done")
                }
            }

            if campaign.followUpTasks.isEmpty {
                Section {
                    ContentUnavailableView {
                        Label("No follow-ups yet", systemImage: "bell.slash")
                    } description: {
                        Text("Add one above, or mark a pitch as sent to be offered a reminder.")
                    }
                }
                .listRowBackground(Color.clear)
            }
        }
        .scrollDismissesKeyboard(.immediately)
        .navigationTitle("Follow-ups")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if addingFocused {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { addingFocused = false }
                }
            }
        }
    }

    private func row(_ task: FollowUpTask) -> some View {
        TaskRow(task: task, toggle: toggle)
            .swipeActions(edge: .trailing) {
                Button(role: .destructive) {
                    withAnimation { modelContext.delete(task) }
                    try? modelContext.save()
                } label: { Label("Delete", systemImage: "trash") }
            }
    }

    private func addTask() {
        let title = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        Haptics.tap()
        addingFocused = false
        let task = FollowUpTask(title: title, dueDate: newDue, campaign: campaign)
        modelContext.insert(task)
        campaign.followUpTasks.append(task)
        try? modelContext.save()
        newTitle = ""
    }

    private func toggle(_ task: FollowUpTask) {
        Haptics.success()
        withAnimation(.snappy) { task.isDone.toggle() }
        try? modelContext.save()
    }
}

private struct TaskRow: View {
    @Bindable var task: FollowUpTask
    let toggle: (FollowUpTask) -> Void

    private var overdue: Bool {
        !task.isDone && (task.dueDate.map { $0 < .now } ?? false)
    }

    var body: some View {
        HStack(spacing: 12) {
            Button { toggle(task) } label: {
                Image(systemName: task.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(task.isDone ? Palette.evidence(.high) : Palette.inkTertiary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(task.isDone ? "Mark not done" : "Mark done")

            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .font(.subheadline)
                    .foregroundStyle(Palette.ink)
                    .strikethrough(task.isDone)
                if let due = task.dueDate {
                    Text(overdue ? "Overdue — \(due.formatted(.relative(presentation: .named)))"
                                 : "Due \(due.formatted(.relative(presentation: .named)))")
                        .font(.caption)
                        .foregroundStyle(overdue ? Palette.warning : Palette.inkTertiary)
                }
            }
            Spacer(minLength: 0)
        }
        .opacity(task.isDone ? 0.6 : 1)
    }
}
