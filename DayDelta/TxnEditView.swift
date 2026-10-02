import SwiftUI

/// Add/edit one transaction. Mirrors EventEditView's style (monospaced, dark).
struct TxnEditView: View {
    let txn: Txn?
    let categories: [Category]
    var defaultDate: Date? = nil
    let onSave: (Txn) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var type: TxnType
    @State private var amount: Decimal?
    @State private var categoryID: UUID?
    @State private var date: Date
    @State private var note: String
    @State private var eventID: UUID?

    private let events = EventStore.load()

    init(txn: Txn?, categories: [Category], defaultDate: Date? = nil,
         onSave: @escaping (Txn) -> Void) {
        self.txn = txn
        self.categories = categories
        self.defaultDate = defaultDate
        self.onSave = onSave
        _type = State(initialValue: txn?.type ?? .expense)
        _amount = State(initialValue: txn?.amount)
        _categoryID = State(initialValue: txn?.categoryID)
        _date = State(initialValue: txn?.date ?? defaultDate ?? Date())
        _note = State(initialValue: txn?.note ?? "")
        _eventID = State(initialValue: txn?.eventID)
    }

    private var typeCategories: [Category] { categories.filter { $0.type == type } }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Type", selection: $type) {
                        Text("Expense").tag(TxnType.expense)
                        Text("Income").tag(TxnType.income)
                    }
                    .pickerStyle(.segmented)
                    TextField("Amount", value: $amount, format: .number)
                        .keyboardType(.decimalPad)
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                }
                Section("Category") {
                    CategoryRadioGroup(categories: typeCategories, selection: $categoryID)
                }
                Section("Note") {
                    TextField("Note", text: $note, axis: .vertical).lineLimit(2...5)
                }
                if !events.isEmpty {
                    Section("Event") {
                        Picker("Event", selection: $eventID) {
                            Text("None").tag(UUID?.none)
                            ForEach(events) { e in Text(e.title).tag(Optional(e.id)) }
                        }
                    }
                }
            }
            .font(.system(.body, design: .monospaced))
            .scrollContentBackground(.hidden)
            .background(Color.black)
            .navigationTitle(txn == nil ? "New" : "Edit")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                }
            }
            // Reset category when switching type so it always belongs to `type`.
            .onChange(of: type) { _, _ in
                if let cid = categoryID, !typeCategories.contains(where: { $0.id == cid }) {
                    categoryID = typeCategories.first?.id
                }
            }
            .onAppear { if categoryID == nil { categoryID = typeCategories.first?.id } }
        }
        .preferredColorScheme(.dark)
        .tint(.white)
    }

    private func save() {
        guard let amount, amount > 0, let categoryID else { return }
        var t = txn ?? Txn(type: type, amount: amount, categoryID: categoryID, date: date)
        t.type = type
        t.amount = amount
        t.categoryID = categoryID
        t.date = date
        t.note = note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : note
        t.eventID = eventID
        onSave(t)
        dismiss()
    }
}
