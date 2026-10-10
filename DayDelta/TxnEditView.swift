import SwiftUI

/// Add/edit one transaction. Custom numeric keypad for the amount (no system
/// keyboard); category and account are chosen on pushed pages.
struct TxnEditView: View {
    /// Mode selector: a plain expense/income txn, or an account-to-account transfer.
    private enum Mode: Hashable { case expense, income, transfer }

    let txn: Txn?
    let categories: [Category]
    var accounts: [Account] = []
    var defaultDate: Date? = nil
    let onSave: (Txn) -> Void
    /// Called for a transfer: (amount, from, to, date, note). Only used when adding.
    var onTransfer: ((Decimal, UUID?, UUID?, Date, String?) -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var mode: Mode
    @State private var amountText: String
    @State private var categoryID: UUID?
    @State private var accountID: UUID?
    @State private var fromID: UUID?
    @State private var toID: UUID?
    @State private var date: Date
    @State private var note: String
    @State private var eventID: UUID?
    /// Bumped on "save & add next" to fire a confirming haptic (the sheet stays open).
    @State private var savedTick = 0

    init(txn: Txn?, categories: [Category], accounts: [Account] = [],
         defaultDate: Date? = nil,
         onTransfer: ((Decimal, UUID?, UUID?, Date, String?) -> Void)? = nil,
         onSave: @escaping (Txn) -> Void) {
        self.txn = txn
        self.categories = categories
        self.accounts = accounts
        self.defaultDate = defaultDate
        self.onTransfer = onTransfer
        self.onSave = onSave
        _mode = State(initialValue: txn?.type == .income ? .income : .expense)
        _amountText = State(initialValue: txn.map { "\($0.amount)" } ?? "")
        _categoryID = State(initialValue: txn?.categoryID)
        _accountID = State(initialValue: txn?.accountID)
        _fromID = State(initialValue: nil)
        _toID = State(initialValue: nil)
        _date = State(initialValue: txn?.date ?? defaultDate ?? Date())
        _note = State(initialValue: txn?.note ?? "")
        _eventID = State(initialValue: txn?.eventID)
    }

    private var type: TxnType { mode == .income ? .income : .expense }
    private var isTransfer: Bool { mode == .transfer }
    private var typeCategories: [Category] { categories.filter { $0.type == type && !$0.isTransfer } }
    private var fromAccount: Account? { accounts.first { $0.id == fromID } }
    private var toAccount: Account? { accounts.first { $0.id == toID } }
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

                Picker("Mode", selection: $mode) {
                    Text("Expense").tag(Mode.expense)
                    Text("Income").tag(Mode.income)
                    if txn == nil { Text("Transfer").tag(Mode.transfer) }
                }
                .pickerStyle(.segmented)

                row("Date") { DatePicker("", selection: $date, displayedComponents: .date).labelsHidden() }

                if isTransfer {
                    NavigationLink {
                        AccountPickerView(accounts: accounts, selection: $fromID)
                    } label: {
                        pickerRow("From", color: fromAccount.map { Color(hex: $0.colorHex) },
                                  value: fromAccount?.name ?? "Select")
                    }
                    NavigationLink {
                        AccountPickerView(accounts: accounts, selection: $toID)
                    } label: {
                        pickerRow("To", color: toAccount.map { Color(hex: $0.colorHex) },
                                  value: toAccount?.name ?? "Select")
                    }
                } else {
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
                if txn == nil {   // adding: offer "save & add next" to batch entries
                    ToolbarItem(placement: .confirmationAction) {
                        Button { saveAndNext() } label: { Image(systemName: "plus.circle") }
                    }
                }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { save() } }
            }
            .sensoryFeedback(.success, trigger: savedTick)
            .onChange(of: mode) { _, _ in
                if let cid = categoryID, !typeCategories.contains(where: { $0.id == cid }) {
                    categoryID = typeCategories.first?.id
                }
                if isTransfer {   // default From = first non-Cash, To = Cash
                    if fromID == nil { fromID = accounts.first(where: { $0.name != "Cash" })?.id ?? accounts.first?.id }
                    if toID == nil { toID = accounts.first(where: { $0.name == "Cash" })?.id ?? accounts.last?.id }
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

    /// Validate + persist the current entry (txn or transfer). Returns false on
    /// invalid input so callers know whether to dismiss / reset.
    private func commit() -> Bool {
        guard let amount = Decimal(string: amountText), amount > 0 else { return false }
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let noteOrNil = trimmedNote.isEmpty ? nil : trimmedNote

        if isTransfer {
            guard let fromID, let toID, fromID != toID else { return false }
            onTransfer?(amount, fromID, toID, date, noteOrNil)
            return true
        }

        guard let categoryID else { return false }
        var t = txn ?? Txn(type: type, amount: amount, categoryID: categoryID, date: date)
        t.type = type
        t.amount = amount
        t.categoryID = categoryID
        t.date = date
        t.note = noteOrNil
        t.eventID = eventID
        t.accountID = accountID
        onSave(t)
        return true
    }

    private func save() { if commit() { dismiss() } }

    /// Save this entry and clear the amount/note for the next one — keeps category,
    /// account, date and mode so logging several in a row is one tap each.
    private func saveAndNext() {
        guard commit() else { return }
        amountText = ""
        note = ""
        savedTick += 1
    }
}
