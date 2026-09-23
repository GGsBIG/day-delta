import SwiftUI

struct EventEditView: View {
    let event: Event?
    let onSave: (Event) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var date: Date
    @State private var mode: CountMode
    @State private var recurrence: Recurrence
    @State private var icon: String?
    @State private var notify: Bool
    @State private var notifyDaysBefore: Int

    init(event: Event?, onSave: @escaping (Event) -> Void) {
        self.event = event
        self.onSave = onSave
        _title = State(initialValue: event?.title ?? "")
        _date = State(initialValue: event?.targetDate ?? Date())
        _mode = State(initialValue: event?.mode ?? .auto)
        _recurrence = State(initialValue: event?.recurrence ?? .none)
        _icon = State(initialValue: event?.icon)
        _notify = State(initialValue: event?.notify ?? false)
        _notifyDaysBefore = State(initialValue: event?.notifyDaysBefore ?? 0)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Title", text: $title)
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                }
                Section("Icon") {
                    IconPicker(selection: $icon)
                }
                Section {
                    Picker("Count", selection: $mode) {
                        Text("Auto (until / since)").tag(CountMode.auto)
                        Text("Day counter").tag(CountMode.dayCounter)
                    }
                    Picker("Repeat", selection: $recurrence) {
                        Text("Never").tag(Recurrence.none)
                        Text("Weekly").tag(Recurrence.weekly)
                        Text("Monthly").tag(Recurrence.monthly)
                        Text("Yearly").tag(Recurrence.yearly)
                    }
                    Toggle("Notify at 9am", isOn: $notify)
                    if notify {
                        Picker("Remind", selection: $notifyDaysBefore) {
                            Text("On the day").tag(0)
                            Text("1 day before").tag(1)
                            Text("3 days before").tag(3)
                            Text("7 days before").tag(7)
                        }
                    }
                }
            }
            .font(.system(.body, design: .monospaced))
            .scrollContentBackground(.hidden)
            .background(Color.black)
            .navigationTitle(event == nil ? "New" : "Edit")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let trimmed = title.trimmingCharacters(in: .whitespaces)
                        guard !trimmed.isEmpty else { return }
                        var e = event ?? Event(title: trimmed, targetDate: date)
                        e.title = trimmed
                        e.targetDate = date
                        e.mode = mode
                        e.recurrence = recurrence
                        e.icon = icon
                        e.notify = notify
                        e.notifyDaysBefore = notify ? notifyDaysBefore : 0
                        onSave(e)
                        dismiss()
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
        .tint(.white)
    }
}

/// Grid of custom SVG icons plus a "none" option; binds to an asset name.
struct IconPicker: View {
    @Binding var selection: String?
    private let columns = [GridItem(.adaptive(minimum: 44), spacing: 12)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            cell(nil)
            ForEach(eventIconNames, id: \.self) { cell($0) }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func cell(_ name: String?) -> some View {
        let selected = selection == name
        Button {
            selection = name
        } label: {
            Group {
                if let name {
                    Image(name).renderingMode(.template).resizable().scaledToFit().padding(9)
                } else {
                    Image(systemName: "nosign").resizable().scaledToFit().padding(11)
                }
            }
            .frame(width: 44, height: 44)
            .foregroundStyle(selected ? Color.black : Color.white)
            .background(selected ? Color.white : Color.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }
}
