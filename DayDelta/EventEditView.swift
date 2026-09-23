import SwiftUI

struct EventEditView: View {
    let event: Event?
    let onSave: (Event) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var date: Date
    @State private var repeatsYearly: Bool

    init(event: Event?, onSave: @escaping (Event) -> Void) {
        self.event = event
        self.onSave = onSave
        _title = State(initialValue: event?.title ?? "")
        _date = State(initialValue: event?.targetDate ?? Date())
        _repeatsYearly = State(initialValue: event?.repeatsYearly ?? false)
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Title", text: $title)
                    .font(.system(.body, design: .monospaced))
                DatePicker("Date", selection: $date, displayedComponents: .date)
                    .font(.system(.body, design: .monospaced))
                Toggle("Repeats yearly", isOn: $repeatsYearly)
                    .font(.system(.body, design: .monospaced))
            }
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
                        e.repeatsYearly = repeatsYearly
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
