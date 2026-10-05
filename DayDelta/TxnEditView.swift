import SwiftUI

/// Add/edit one transaction. Custom numeric keypad for the amount (no system
/// keyboard); category and account are chosen on pushed pages.
struct TxnEditView: View {
    let txn: Txn?
    let categories: [Category]
    var accounts: [Account] = []
    var defaultDate: Date? = nil
    let onSave: (Txn) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var type: TxnType
    @State private var amountText: String
    @State private var categoryID: UUID?
    @State private var accountID: UUID?
    @State private var date: Date
    @State private var note: String
    @State private var eventID: UUID?

    init(txn: Txn?, categories: [Category], accounts: [Account] = [],
         defaultDate: Date? = nil, onSave: @escaping (Txn) -> Void) {
        self.txn = txn
        self.categories = categories
        self.accounts = accounts
        self.defaultDate = defaultDate
        self.onSave = onSave
        _type = State(initialValue: txn?.type ?? .expense)
        _amountText = State(initialValue: txn.map { "\($0.amount)" } ?? "")
        _categoryID = State(initialValue: txn?.categoryID)
        _accountID = State(initialValue: txn?.accountID)
        _date = State(initialValue: txn?.date ?? defaultDate ?? Date())
        _note = State(initialValue: txn?.note ?? "")
        _eventID = State(initialValue: txn?.eventID)
    }

    private var typeCategories: [Category] { categories.filter { $0.type == type } }
    private var selectedCategory: Category? { categories.first { $0.id == categoryID } }
    private var selectedAccount: Account? { accounts.first { $0.id == accountID } }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text(amountText.isEmpty ? "0" : amountText)
                    .font(.system(size: 48, design: .rounded))
                    .foregroundStyle(Color.appInk)
                    .minimumScaleFactor(0.4).lineLimit(1)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)

                Picker("Type", selection: $type) {
                    Text("Expense").tag(TxnType.expense)
                    Text("Income").tag(TxnType.income)
                }
                .pickerStyle(.segmented)

                row("Date") { DatePicker("", selection: $date, displayedComponents: .date).labelsHidden() }

                NavigationLink {
                    CategoryPickerView(categories: typeCategories, selection: $categoryID)
                } label: {
                    pickerRow("Category", color: selectedCategory.map { Color(hex: $0.colorHex) },
                              value: selectedCategory?.name ?? "Select")
                }

                NavigationLink {
                    AccountPickerView(accounts: accounts, selection: $accountID)
                } label: {
                    pickerRow("Account", color: selectedAccount.map { Color(hex: $0.colorHex) },
                              value: selectedAccount?.name ?? "Select")
                }

                row("Note") {
                    TextField("Note", text: $note)
                        .multilineTextAlignment(.trailing)
                        .font(.system(.body, design: .rounded))
                }

                Spacer(minLength: 0)
                Keypad(amount: $amountText)
            }
            .padding(.horizontal)
            .background(GrainientBackground())
            .navigationTitle(txn == nil ? "New" : "Edit")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { save() } }
            }
            .onChange(of: type) { _, _ in
                if let cid = categoryID, !typeCategories.contains(where: { $0.id == cid }) {
                    categoryID = typeCategories.first?.id
                }
            }
            .onAppear {
                if categoryID == nil { categoryID = typeCategories.first?.id }
                if accountID == nil { accountID = accounts.first?.id }
            }
        }
        .preferredColorScheme(.dark)
        .tint(.white)
    }

    @ViewBuilder
    private func row<Content: View>(_ label: String,
                                    @ViewBuilder _ content: () -> Content) -> some View {
        HStack {
            Text(label).foregroundStyle(Color.appInk.opacity(0.6))
            Spacer()
            content()
        }
        .font(.system(.body, design: .rounded))
        .padding(.vertical, 6)
    }

    private func pickerRow(_ label: String, color: Color?, value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(Color.appInk.opacity(0.6))
            Spacer()
            if let color { Circle().fill(color).frame(width: 12, height: 12) }
            Text(value).foregroundStyle(Color.appInk)
            Image(systemName: "chevron.right").foregroundStyle(Color.appInk.opacity(0.6)).font(.caption)
        }
        .font(.system(.body, design: .rounded))
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }

    private func save() {
        guard let amount = Decimal(string: amountText), amount > 0,
              let categoryID else { return }
        var t = txn ?? Txn(type: type, amount: amount, categoryID: categoryID, date: date)
        t.type = type
        t.amount = amount
        t.categoryID = categoryID
        t.date = date
        t.note = note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : note
        t.eventID = eventID
        t.accountID = accountID
        onSave(t)
        dismiss()
    }
}
