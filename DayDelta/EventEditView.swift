import SwiftUI
import PhotosUI

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
    @State private var note: String
    @State private var photoFile: String?
    @State private var pickerItem: PhotosPickerItem?
    @State private var label: String

    private let labelPresets = ["days", "days together", "days left",
                                "days ago", "days to go", "nights"]

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
        _note = State(initialValue: event?.note ?? "")
        _photoFile = State(initialValue: event?.photoFile)
        _label = State(initialValue: event?.label ?? "")
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
                Section("Photo") {
                    if let photoFile, let ui = PhotoStore.load(photoFile) {
                        Image(uiImage: ui)
                            .resizable().scaledToFill()
                            .frame(height: 160).frame(maxWidth: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .listRowInsets(EdgeInsets())
                    }
                    PhotosPicker(selection: $pickerItem, matching: .images) {
                        Label(photoFile == nil ? "Add photo" : "Replace photo",
                              systemImage: "photo")
                    }
                    if photoFile != nil {
                        Button(role: .destructive) { removePhoto() } label: {
                            Label("Remove photo", systemImage: "trash")
                        }
                    }
                }
                Section("Note") {
                    TextField("Note", text: $note, axis: .vertical)
                        .lineLimit(3...8)
                }
                Section("Label") {
                    TextField("Auto", text: $label)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            labelChip("Auto", value: "")
                            ForEach(labelPresets, id: \.self) { labelChip($0, value: $0) }
                        }
                    }
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
                        e.note = note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? nil : note
                        e.photoFile = photoFile
                        let l = label.trimmingCharacters(in: .whitespaces)
                        e.label = l.isEmpty ? nil : l
                        onSave(e)
                        dismiss()
                    }
                }
            }
            .onChange(of: pickerItem) { _, item in loadPhoto(item) }
        }
        .preferredColorScheme(.dark)
        .tint(.white)
    }

    private func loadPhoto(_ item: PhotosPickerItem?) {
        guard let item else { return }
        Task {
            if let data = try? await item.loadTransferable(type: Data.self),
               let name = PhotoStore.save(data) {
                if let old = photoFile { PhotoStore.delete(old) }
                photoFile = name
            }
        }
    }

    private func labelChip(_ title: String, value: String) -> some View {
        let selected = label == value
        return Button {
            label = value
        } label: {
            Text(title)
                .font(.system(.caption, design: .monospaced))
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(selected ? Color.white : Color.white.opacity(0.1))
                .foregroundStyle(selected ? Color.black : Color.white)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func removePhoto() {
        if let old = photoFile { PhotoStore.delete(old) }
        photoFile = nil
        pickerItem = nil
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
