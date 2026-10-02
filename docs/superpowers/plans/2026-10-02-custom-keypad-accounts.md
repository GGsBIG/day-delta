# Custom Keypad, Push Pickers & Accounts Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the system keyboard with a custom numeric keypad, select category/account via pushed pages that pop on tap, and add a full customizable Account system.

**Architecture:** Account mirrors Category (`Codable` + UserDefaults store + builtins). Amount editing is a pure string function (`applyAmountKey`, unit-tested) driven by a custom `Keypad` view; the amount is a display, not a `TextField`. Category/Account selection are pushed list views that `dismiss()` on tap. A combined manage screen hosts both managers.

**Tech Stack:** Swift 5, SwiftUI, iOS 17+. No new dependencies.

**Spec:** `docs/superpowers/specs/2026-10-02-custom-keypad-accounts-design.md`

**Commands:**
- Logic tests: `swiftc Shared/DayMath.swift Shared/Money.swift tests/main.swift -o /tmp/t && /tmp/t`
- Build: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -scheme DayDelta -destination 'generic/platform=iOS Simulator' build CODE_SIGNING_ALLOWED=NO 2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED"` (run `DEVELOPER_DIR=... xcodegen generate` first if `.xcodeproj` missing or after adding/deleting a source file)

---

## File Structure

- Modify `Shared/Money.swift` — `Account` + `AccountStore` + builtins; `Txn.accountID`; `AmountKey` + `applyAmountKey`.
- Modify `tests/main.swift` — `applyAmountKey` asserts.
- Create `DayDelta/Keypad.swift`, `DayDelta/CategoryPickerView.swift`, `DayDelta/AccountPickerView.swift`, `DayDelta/AccountManagerView.swift`, `DayDelta/ManageView.swift`.
- Delete `DayDelta/CategoryDropdown.swift`.
- Modify `DayDelta/TxnEditView.swift`, `DayDelta/LedgerView.swift`, `DayDelta/Backup.swift`, `DayDelta/ContentView.swift`.

SwiftUI views have no standalone compile check — each view task verifies with the full Xcode build. Ignore per-file SourceKit "cannot find type" warnings.

---

## Task 1: Account model, store, and Txn.accountID

**Files:**
- Modify: `Shared/Money.swift`

- [ ] **Step 1: Add `accountID` to Txn**

In `Shared/Money.swift`, find:
```swift
    var note: String?
    var eventID: UUID?        // optional link to a countdown Event
}
```
Replace with:
```swift
    var note: String?
    var eventID: UUID?        // optional link to a countdown Event
    var accountID: UUID?      // optional payment account; nil for legacy rows
}
```
(Synthesized `Codable` decodes a missing optional key as nil, so existing transactions still load — same as `eventID`.)

- [ ] **Step 2: Add the Account model, builtins, and store**

In `Shared/Money.swift`, find:
```swift
enum TxnStore {
    private static let key = "daydelta.txns"
```
Insert ABOVE that `enum TxnStore {` line:
```swift
/// A payment account/method (Cash, Bank, …). Builtins can be renamed/recolored
/// but not deleted. Mirrors Category, minus the type split.
struct Account: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var colorHex: String
    var builtin: Bool = false
}

extension Account {
    static let builtins: [Account] = [
        .init(name: "Cash", colorHex: "#22C55E", builtin: true),
        .init(name: "Bank", colorHex: "#4F9DFF", builtin: true),
        .init(name: "Credit Card", colorHex: "#F59E0B", builtin: true),
    ]
}

enum AccountStore {
    private static let key = "daydelta.accounts"

    static func load() -> [Account] {
        if let data = UserDefaults.standard.data(forKey: key),
           let accs = try? JSONDecoder().decode([Account].self, from: data),
           !accs.isEmpty {
            return accs
        }
        save(Account.builtins)
        return Account.builtins
    }

    static func save(_ accs: [Account]) {
        guard let data = try? JSONEncoder().encode(accs) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}

```

- [ ] **Step 3: Verify tests still compile/pass and build**

Run: `swiftc Shared/DayMath.swift Shared/Money.swift tests/main.swift -o /tmp/t && /tmp/t`
Expected: PASS (both lines print).
Then the build command. Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Commit**

```bash
git add Shared/Money.swift
git commit -m "feat: Account model/store and Txn.accountID"
```

---

## Task 2: Amount keypad logic (TDD)

**Files:**
- Modify: `Shared/Money.swift`
- Test: `tests/main.swift`

- [ ] **Step 1: Write the failing tests**

In `tests/main.swift`, find `print("all money tests passed")` and insert immediately BEFORE it:
```swift
// applyAmountKey: build digits, single dot, max 2 decimals, delete
assert(applyAmountKey("", .digit(1)) == "1")
assert(applyAmountKey("1", .digit(2)) == "12")
assert(applyAmountKey("0", .digit(5)) == "5")        // leading zero replaced
assert(applyAmountKey("", .dot) == "0.")             // dot on empty -> 0.
assert(applyAmountKey("0.", .dot) == "0.")           // no second dot
assert(applyAmountKey("1.23", .digit(4)) == "1.23")  // max 2 decimals
assert(applyAmountKey("1.2", .digit(5)) == "1.25")
assert(applyAmountKey("12", .delete) == "1")
assert(applyAmountKey("1", .delete) == "")
assert(applyAmountKey("", .delete) == "")
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swiftc Shared/DayMath.swift Shared/Money.swift tests/main.swift -o /tmp/t && /tmp/t`
Expected: FAIL — `cannot find 'applyAmountKey' in scope`.

- [ ] **Step 3: Implement**

Append to `Shared/Money.swift`:
```swift
// MARK: - Amount keypad

enum AmountKey: Equatable {
    case digit(Int)
    case dot
    case delete
}

/// Pure edit of the amount string for the custom keypad. Enforces a single
/// decimal point and at most two fractional digits; a typed digit replaces a
/// lone leading "0". Delete removes the last character.
func applyAmountKey(_ s: String, _ key: AmountKey) -> String {
    switch key {
    case .delete:
        return String(s.dropLast())
    case .dot:
        if s.contains(".") { return s }
        return s.isEmpty ? "0." : s + "."
    case .digit(let d):
        if let dot = s.firstIndex(of: ".") {
            let decimals = s.distance(from: s.index(after: dot), to: s.endIndex)
            if decimals >= 2 { return s }
        }
        if s == "0" { return "\(d)" }
        return s + "\(d)"
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swiftc Shared/DayMath.swift Shared/Money.swift tests/main.swift -o /tmp/t && /tmp/t`
Expected: PASS — both lines print.

- [ ] **Step 5: Commit**

```bash
git add Shared/Money.swift tests/main.swift
git commit -m "feat: amount keypad edit logic with tests"
```

---

## Task 3: Keypad view

**Files:**
- Create: `DayDelta/Keypad.swift`

- [ ] **Step 1: Create the file**

Create `DayDelta/Keypad.swift`:
```swift
import SwiftUI

/// Custom numeric keypad that edits an amount string via `applyAmountKey`.
struct Keypad: View {
    @Binding var amount: String

    private let rows: [[AmountKey]] = [
        [.digit(1), .digit(2), .digit(3)],
        [.digit(4), .digit(5), .digit(6)],
        [.digit(7), .digit(8), .digit(9)],
        [.dot, .digit(0), .delete],
    ]

    var body: some View {
        VStack(spacing: 10) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: 10) {
                    ForEach(Array(row.enumerated()), id: \.offset) { _, key in
                        keyButton(key)
                    }
                }
            }
        }
        .padding(12)
    }

    private func keyButton(_ key: AmountKey) -> some View {
        Button {
            amount = applyAmountKey(amount, key)
        } label: {
            Text(label(key))
                .font(.system(.title2, design: .monospaced))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color(white: 0.12)))
        }
        .buttonStyle(.plain)
    }

    private func label(_ key: AmountKey) -> String {
        switch key {
        case .digit(let d): return "\(d)"
        case .dot: return "."
        case .delete: return "⌫"
        }
    }
}
```

- [ ] **Step 2: Verify the build**

Run the build command. Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add DayDelta/Keypad.swift
git commit -m "feat: custom numeric keypad view"
```

---

## Task 4: Category & Account picker pages

**Files:**
- Create: `DayDelta/CategoryPickerView.swift`
- Create: `DayDelta/AccountPickerView.swift`

- [ ] **Step 1: Create CategoryPickerView**

Create `DayDelta/CategoryPickerView.swift`:
```swift
import SwiftUI

/// Pushed category chooser. Tapping a row sets the selection and pops back.
struct CategoryPickerView: View {
    let categories: [Category]
    @Binding var selection: UUID?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            ForEach(categories) { c in
                Button {
                    selection = c.id
                    dismiss()
                } label: {
                    HStack(spacing: 10) {
                        Circle().fill(Color(hex: c.colorHex)).frame(width: 12, height: 12)
                        Text(c.name)
                        Spacer()
                        if selection == c.id { Image(systemName: "checkmark").foregroundStyle(.white) }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .listRowBackground(Color.black)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.black)
        .font(.system(.body, design: .monospaced))
        .foregroundStyle(.white)
        .navigationTitle("Category")
    }
}
```

- [ ] **Step 2: Create AccountPickerView**

Create `DayDelta/AccountPickerView.swift`:
```swift
import SwiftUI

/// Pushed account chooser. Tapping a row sets the selection and pops back.
struct AccountPickerView: View {
    let accounts: [Account]
    @Binding var selection: UUID?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            ForEach(accounts) { a in
                Button {
                    selection = a.id
                    dismiss()
                } label: {
                    HStack(spacing: 10) {
                        Circle().fill(Color(hex: a.colorHex)).frame(width: 12, height: 12)
                        Text(a.name)
                        Spacer()
                        if selection == a.id { Image(systemName: "checkmark").foregroundStyle(.white) }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .listRowBackground(Color.black)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.black)
        .font(.system(.body, design: .monospaced))
        .foregroundStyle(.white)
        .navigationTitle("Account")
    }
}
```

- [ ] **Step 3: Verify the build**

Run the build command. Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Commit**

```bash
git add DayDelta/CategoryPickerView.swift DayDelta/AccountPickerView.swift
git commit -m "feat: pushed category and account picker pages"
```

---

## Task 5: Account manager

**Files:**
- Create: `DayDelta/AccountManagerView.swift`

- [ ] **Step 1: Create the file**

Create `DayDelta/AccountManagerView.swift`:
```swift
import SwiftUI

/// Add / rename / recolor / delete accounts. Built-ins can't be deleted.
struct AccountManagerView: View {
    @Binding var accounts: [Account]

    @State private var editing: Account?

    private let colors = ["#4F9DFF", "#A855F7", "#F59E0B", "#22C55E",
                          "#EF4444", "#14B8A6", "#EC4899", "#9CA3AF"]

    var body: some View {
        List {
            ForEach(accounts) { a in
                Button { editing = a } label: { row(a) }
                    .buttonStyle(.plain)
            }
            .onDelete { offsets in delete(offsets) }
            Button {
                editing = Account(name: "", colorHex: colors[0])
            } label: {
                Label("Add account", systemImage: "plus")
            }
        }
        .font(.system(.body, design: .monospaced))
        .scrollContentBackground(.hidden)
        .background(Color.black)
        .navigationTitle("Accounts")
        .sheet(item: $editing) { a in
            AccountEditSheet(account: a, colors: colors) { saved in
                if let i = accounts.firstIndex(where: { $0.id == saved.id }) {
                    accounts[i] = saved
                } else {
                    accounts.append(saved)
                }
                editing = nil
            }
        }
    }

    private func row(_ a: Account) -> some View {
        HStack {
            Circle().fill(Color(hex: a.colorHex)).frame(width: 14, height: 14)
            Text(a.name.isEmpty ? "(unnamed)" : a.name)
            Spacer()
            if a.builtin { Text("built-in").foregroundStyle(.gray).font(.caption) }
        }
    }

    /// Only non-builtin accounts delete; builtins silently skip.
    private func delete(_ offsets: IndexSet) {
        let ids = offsets.map { accounts[$0] }.filter { !$0.builtin }.map { $0.id }
        accounts.removeAll { ids.contains($0.id) }
    }
}

private struct AccountEditSheet: View {
    @State var account: Account
    let colors: [String]
    let onSave: (Account) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $account.name)
                Section("Color") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 40))], spacing: 12) {
                        ForEach(colors, id: \.self) { hex in
                            Circle()
                                .fill(Color(hex: hex))
                                .frame(width: 32, height: 32)
                                .overlay(Circle().strokeBorder(
                                    account.colorHex == hex ? Color.white : .clear, lineWidth: 2))
                                .onTapGesture { account.colorHex = hex }
                        }
                    }
                }
            }
            .font(.system(.body, design: .monospaced))
            .scrollContentBackground(.hidden)
            .background(Color.black)
            .navigationTitle(account.name.isEmpty ? "New account" : account.name)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let n = account.name.trimmingCharacters(in: .whitespaces)
                        guard !n.isEmpty else { return }
                        account.name = n
                        onSave(account)
                        dismiss()
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
        .tint(.white)
    }
}
```

- [ ] **Step 2: Verify the build**

Run the build command. Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add DayDelta/AccountManagerView.swift
git commit -m "feat: account manager"
```

---

## Task 6: Rewrite TxnEditView (keypad + push pickers + account)

**Files:**
- Modify: `DayDelta/TxnEditView.swift`
- Delete: `DayDelta/CategoryDropdown.swift`

- [ ] **Step 1: Replace the whole file**

Replace the ENTIRE contents of `DayDelta/TxnEditView.swift` with:
```swift
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
                    .font(.system(size: 48, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
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
                        .font(.system(.body, design: .monospaced))
                }

                Spacer(minLength: 0)
                Keypad(amount: $amountText)
            }
            .padding(.horizontal)
            .background(Color.black)
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
            Text(label).foregroundStyle(.gray)
            Spacer()
            content()
        }
        .font(.system(.body, design: .monospaced))
        .padding(.vertical, 6)
    }

    private func pickerRow(_ label: String, color: Color?, value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(.gray)
            Spacer()
            if let color { Circle().fill(color).frame(width: 12, height: 12) }
            Text(value).foregroundStyle(.white)
            Image(systemName: "chevron.right").foregroundStyle(.gray).font(.caption)
        }
        .font(.system(.body, design: .monospaced))
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
```

- [ ] **Step 2: Delete the dropdown**

Run:
```bash
git rm DayDelta/CategoryDropdown.swift
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodegen generate
```

- [ ] **Step 3: Verify the build**

Run the build command. Expected: `** BUILD SUCCEEDED **` (LedgerView still calls `TxnEditView(txn:categories:defaultDate:)` / `(txn:categories:)`; `accounts` defaults to `[]`, so it compiles — accounts are wired in Task 7).

- [ ] **Step 4: Commit**

```bash
git add DayDelta/TxnEditView.swift DayDelta/CategoryDropdown.swift
git commit -m "feat: transaction editor with custom keypad and push pickers"
```

---

## Task 7: Accounts state + combined manage screen in LedgerView

**Files:**
- Create: `DayDelta/ManageView.swift`
- Modify: `DayDelta/LedgerView.swift`

- [ ] **Step 1: Create the combined manage screen**

Create `DayDelta/ManageView.swift`:
```swift
import SwiftUI

/// The Money tab's Edit screen: a segmented switch between the category and
/// account managers.
struct ManageView: View {
    @Binding var categories: [Category]
    @Binding var accounts: [Account]
    @State private var tab = 0

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("", selection: $tab) {
                    Text("Categories").tag(0)
                    Text("Accounts").tag(1)
                }
                .pickerStyle(.segmented)
                .padding()

                if tab == 0 {
                    CategoryManagerView(categories: $categories)
                } else {
                    AccountManagerView(accounts: $accounts)
                }
            }
            .background(Color.black)
        }
        .preferredColorScheme(.dark)
        .tint(.white)
    }
}
```

> `CategoryManagerView`/`AccountManagerView` already set their own `.navigationTitle`;
> nesting them under this `NavigationStack` is fine.

- [ ] **Step 2: Add accounts state to LedgerView**

In `DayDelta/LedgerView.swift`, find:
```swift
    @State private var txns: [Txn] = TxnStore.load()
    @State private var categories: [Category] = CategoryStore.load()
```
Replace with:
```swift
    @State private var txns: [Txn] = TxnStore.load()
    @State private var categories: [Category] = CategoryStore.load()
    @State private var accounts: [Account] = AccountStore.load()
```

- [ ] **Step 3: Rename the manage flag and point Edit at ManageView**

In `DayDelta/LedgerView.swift`, find:
```swift
    @State private var managingCategories = false
```
Replace with:
```swift
    @State private var managing = false
```

Find:
```swift
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Edit") { managingCategories = true }
                }
```
Replace with:
```swift
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Edit") { managing = true }
                }
```

Find:
```swift
            .sheet(isPresented: $managingCategories) {
                NavigationStack { CategoryManagerView(categories: $categories) }
                    .preferredColorScheme(.dark).tint(.white)
                    .onDisappear { CategoryStore.save(categories) }
            }
```
Replace with:
```swift
            .sheet(isPresented: $managing) {
                ManageView(categories: $categories, accounts: $accounts)
                    .onDisappear {
                        CategoryStore.save(categories)
                        AccountStore.save(accounts)
                    }
            }
```

- [ ] **Step 4: Pass accounts to both editors and reload on appear**

Find:
```swift
            .sheet(isPresented: $requestAddTxn) {
                TxnEditView(txn: nil, categories: categories, defaultDate: selectedDay) { saved in
                    txns.append(saved); persist()
                }
            }
            .sheet(item: $editingTxn) { t in
                TxnEditView(txn: t, categories: categories) { saved in
                    if let i = txns.firstIndex(where: { $0.id == saved.id }) { txns[i] = saved }
                    persist()
                }
            }
```
Replace with:
```swift
            .sheet(isPresented: $requestAddTxn) {
                TxnEditView(txn: nil, categories: categories, accounts: accounts,
                            defaultDate: selectedDay) { saved in
                    txns.append(saved); persist()
                }
            }
            .sheet(item: $editingTxn) { t in
                TxnEditView(txn: t, categories: categories, accounts: accounts) { saved in
                    if let i = txns.firstIndex(where: { $0.id == saved.id }) { txns[i] = saved }
                    persist()
                }
            }
```

Find:
```swift
        .onAppear {
            txns = TxnStore.load()
            categories = CategoryStore.load()
        }
```
Replace with:
```swift
        .onAppear {
            txns = TxnStore.load()
            categories = CategoryStore.load()
            accounts = AccountStore.load()
        }
```

- [ ] **Step 5: Verify the build**

Run the build command. Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 6: Commit**

```bash
git add DayDelta/ManageView.swift DayDelta/LedgerView.swift
git commit -m "feat: accounts state and combined manage screen"
```

---

## Task 8: Accounts in backup

**Files:**
- Modify: `DayDelta/Backup.swift`
- Modify: `DayDelta/ContentView.swift`

- [ ] **Step 1: Add accounts to BackupData**

In `DayDelta/Backup.swift`, find:
```swift
struct BackupData: Codable {
    var events: [Event]
    var txns: [Txn]
    var categories: [Category]
}
```
Replace with:
```swift
struct BackupData: Codable {
    var events: [Event]
    var txns: [Txn]
    var categories: [Category]
    var accounts: [Account] = []   // default so older backups (no accounts) decode
}
```

- [ ] **Step 2: Include accounts in export**

In `DayDelta/ContentView.swift`, find:
```swift
    private func exportData() -> Data {
        let payload = BackupData(events: events,
                                 txns: TxnStore.load(),
                                 categories: CategoryStore.load())
        return (try? JSONEncoder().encode(payload)) ?? Data()
    }
```
Replace with:
```swift
    private func exportData() -> Data {
        let payload = BackupData(events: events,
                                 txns: TxnStore.load(),
                                 categories: CategoryStore.load(),
                                 accounts: AccountStore.load())
        return (try? JSONEncoder().encode(payload)) ?? Data()
    }
```

- [ ] **Step 3: Merge accounts on import**

In `DayDelta/ContentView.swift`, find:
```swift
        if let backup = try? JSONDecoder().decode(BackupData.self, from: data) {
            merge(backup.events)
            mergeTxns(backup.txns)
            mergeCategories(backup.categories)
        } else if let legacy = try? JSONDecoder().decode([Event].self, from: data) {
```
Replace with:
```swift
        if let backup = try? JSONDecoder().decode(BackupData.self, from: data) {
            merge(backup.events)
            mergeTxns(backup.txns)
            mergeCategories(backup.categories)
            mergeAccounts(backup.accounts)
        } else if let legacy = try? JSONDecoder().decode([Event].self, from: data) {
```

Find:
```swift
    private func mergeCategories(_ imported: [Category]) {
        var cats = CategoryStore.load()
        for c in imported {
            if let i = cats.firstIndex(where: { $0.id == c.id }) { cats[i] = c }
            else { cats.append(c) }
        }
        CategoryStore.save(cats)
    }
```
Insert AFTER it:
```swift

    private func mergeAccounts(_ imported: [Account]) {
        var accs = AccountStore.load()
        for a in imported {
            if let i = accs.firstIndex(where: { $0.id == a.id }) { accs[i] = a }
            else { accs.append(a) }
        }
        AccountStore.save(accs)
    }
```

- [ ] **Step 4: Verify the build**

Run the build command. Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
git add DayDelta/Backup.swift DayDelta/ContentView.swift
git commit -m "feat: include accounts in backup export/import"
```

---

## Task 9: Run it on the simulator

**Files:** none (verification).

- [ ] **Step 1: Build, install, launch** (same as prior runs)

```bash
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
xcodegen generate
xcodebuild -scheme DayDelta -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/dd-dd build CODE_SIGNING_ALLOWED=NO 2>&1 | grep -E "BUILD SUCCEEDED|BUILD FAILED|error:"
xcrun simctl boot "iPhone 17" 2>/dev/null; open -a Simulator
APP=$(find /tmp/dd-dd/Build/Products -name "DayDelta.app" -maxdepth 3 | head -1)
xcrun simctl install "iPhone 17" "$APP"
xcrun simctl launch "iPhone 17" com.tcsxft.daydelta.app
```

- [ ] **Step 2: Confirm behavior**

On Money → Add: the custom keypad types the amount (no system keyboard); the big
amount display updates; Category and Account are rows that push a list and pop on
tap; a new transaction defaults Account to the first one. Top-right Edit shows a
Categories/Accounts segmented manager. Screenshot the editor and inspect.

> To capture cleanly, reuse the prior approach (stub `Notifications.requestAuthIfNeeded`,
> default tab to Money + `requestAddTxn` true), then revert.

No commit — verification only.

---

## Self-review notes

- **Spec coverage:** keypad (Tasks 2–3, wired in Task 6); category push page (Task 4,
  Task 6); account model/store/builtins + `Txn.accountID` (Task 1); account push page
  (Task 4, Task 6); account manager (Task 5); combined Edit screen (Task 7); backup
  accounts (Task 8); simulator verify (Task 9).
- **Type consistency:** `Account`, `AccountStore`, `Account.builtins`, `AmountKey`,
  `applyAmountKey`, `Keypad(amount:)`, `CategoryPickerView(categories:selection:)`,
  `AccountPickerView(accounts:selection:)`, `TxnEditView(txn:categories:accounts:defaultDate:onSave:)`,
  `ManageView(categories:accounts:)` used consistently. `Color(hex:)` reused.
- **Build-order safety:** Tasks 1–5 are additive (old TxnEditView + CategoryDropdown
  still compile). Task 6 rewrites TxnEditView with `accounts` defaulting to `[]`, so
  LedgerView's existing calls still build before Task 7 wires accounts in.
- **Back-compat:** `Txn.accountID` optional (missing key → nil); `BackupData.accounts`
  defaulted so older backups decode.
- **Deferred:** account balances/transfers, per-account Stats filter, custom keyboard
  for the Note field.
