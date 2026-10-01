# Expense Tracking (記帳) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an income/expense ledger to DayDelta with a new "記帳" tab (明細 + 統計 sub-pages), donut + waffle charts, built-in + custom categories, and optional linking of transactions to countdown events.

**Architecture:** Mirror the existing `Event` pattern exactly — `Codable` structs persisted as JSON in `UserDefaults`, pure logic in `Shared/` (compiled standalone for tests), SwiftUI views in `DayDelta/`. Charts use native Swift Charts (`SectorMark`); waffle is a `LazyVGrid`. The app's root becomes a `TabView`.

**Tech Stack:** Swift 5, SwiftUI, Swift Charts, iOS 17+. No new dependencies.

**Spec:** `docs/superpowers/specs/2026-10-01-expense-tracking-design.md`

---

## File Structure

- Create `Shared/Money.swift` — `TxnType`, `Txn`, `Category`, `TxnStore`, `CategoryStore`, built-in category seed, `StatPeriod`, and pure stat/format functions (Foundation only, so the test harness can compile it standalone).
- Create `DayDelta/TxnEditView.swift` — add/edit transaction sheet (mirrors `EventEditView`).
- Create `DayDelta/CategoryManagerView.swift` — list/add/rename/recolor/delete categories.
- Create `DayDelta/LedgerView.swift` — 記帳 tab container: sub-page `Picker`, shared `@State`, persistence, the 明細 list + month summary, and a `Color(hex:)` helper.
- Create `DayDelta/StatsView.swift` — 統計 page: period/type toggles, donut, breakdown list, waffle.
- Modify `DayDelta/DayDeltaApp.swift` — wrap root in `TabView`.
- Modify `DayDelta/MemoryDetailView.swift` — add a "這趟花費" spending line.
- Modify `DayDelta/Backup.swift` + `DayDelta/ContentView.swift` — versioned backup wrapper covering events + txns + categories (back-compatible with old event-only backups).
- Modify `tests/main.swift` — append money-logic asserts.

**Test command (used throughout):**
```
swiftc Shared/DayMath.swift Shared/Money.swift tests/main.swift -o /tmp/daydelta_test && /tmp/daydelta_test
```

---

## Task 1: Money models, stores, and built-in categories

**Files:**
- Create: `Shared/Money.swift`

- [ ] **Step 1: Create the models, stores, and seed**

Create `Shared/Money.swift`:

```swift
import Foundation

enum TxnType: String, Codable, CaseIterable {
    case expense
    case income
}

/// One ledger entry. Money is `Decimal` — never `Double` — so sums don't drift.
struct Txn: Codable, Identifiable, Hashable {
    var id = UUID()
    var type: TxnType
    var amount: Decimal
    var categoryID: UUID
    var date: Date
    var note: String?
    var eventID: UUID?        // optional link to a countdown Event
}

/// A spending/earning bucket. `builtin` categories can be renamed/recolored but
/// not deleted.
struct Category: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var type: TxnType
    var icon: String?         // asset name, reuses eventIconNames
    var colorHex: String      // "#RRGGBB", drives donut/waffle
    var builtin: Bool = false
}

extension Category {
    /// Seeded on first launch. IDs are per-process stable (a `static let`), then
    /// persisted by `CategoryStore.load()`, so they stay fixed after first run.
    static let builtins: [Category] = [
        .init(name: "餐飲", type: .expense, icon: nil, colorHex: "#4F9DFF", builtin: true),
        .init(name: "交通", type: .expense, icon: nil, colorHex: "#A855F7", builtin: true),
        .init(name: "購物", type: .expense, icon: nil, colorHex: "#F59E0B", builtin: true),
        .init(name: "娛樂", type: .expense, icon: nil, colorHex: "#22C55E", builtin: true),
        .init(name: "居住", type: .expense, icon: nil, colorHex: "#EF4444", builtin: true),
        .init(name: "醫療", type: .expense, icon: nil, colorHex: "#14B8A6", builtin: true),
        .init(name: "其他", type: .expense, icon: nil, colorHex: "#9CA3AF", builtin: true),
        .init(name: "薪資", type: .income, icon: nil, colorHex: "#22C55E", builtin: true),
        .init(name: "獎金", type: .income, icon: nil, colorHex: "#4F9DFF", builtin: true),
        .init(name: "投資", type: .income, icon: nil, colorHex: "#F59E0B", builtin: true),
        .init(name: "其他", type: .income, icon: nil, colorHex: "#9CA3AF", builtin: true),
    ]
}

enum TxnStore {
    private static let key = "daydelta.txns"

    static func load() -> [Txn] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let txns = try? JSONDecoder().decode([Txn].self, from: data)
        else { return [] }
        return txns
    }

    static func save(_ txns: [Txn]) {
        guard let data = try? JSONEncoder().encode(txns) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}

enum CategoryStore {
    private static let key = "daydelta.categories"

    /// Returns stored categories, seeding the built-ins on first run.
    static func load() -> [Category] {
        if let data = UserDefaults.standard.data(forKey: key),
           let cats = try? JSONDecoder().decode([Category].self, from: data),
           !cats.isEmpty {
            return cats
        }
        save(Category.builtins)
        return Category.builtins
    }

    static func save(_ cats: [Category]) {
        guard let data = try? JSONEncoder().encode(cats) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}
```

- [ ] **Step 2: Verify it compiles with the test harness**

Run: `swiftc Shared/DayMath.swift Shared/Money.swift tests/main.swift -o /tmp/daydelta_test && /tmp/daydelta_test`
Expected: compiles cleanly, still prints `all DayMath tests passed`.

- [ ] **Step 3: Commit**

```bash
git add Shared/Money.swift
git commit -m "feat: ledger models, stores, and built-in categories"
```

---

## Task 2: Pure stat & format functions (TDD)

**Files:**
- Modify: `Shared/Money.swift`
- Test: `tests/main.swift`

- [ ] **Step 1: Write the failing tests**

Append to `tests/main.swift`, before the final `print(...)` line is fine — but the existing file ends with `print("all DayMath tests passed")`. Add these lines **above** that print, and add a second print at the very end:

```swift
// ---- Money logic ----

func cat(_ hex: String = "#000000") -> Category {
    Category(name: "c", type: .expense, icon: nil, colorHex: hex)
}
let foodID = UUID(), rideID = UUID(), payID = UUID()
func tx(_ amt: Decimal, _ cid: UUID, _ d: Date, _ type: TxnType = .expense) -> Txn {
    Txn(type: type, amount: amt, categoryID: cid, date: d)
}

let sample = [
    tx(100, foodID, day(2026, 6, 10)),
    tx(50,  foodID, day(2026, 6, 20)),
    tx(30,  rideID, day(2026, 6, 15)),
    tx(999, foodID, day(2026, 5, 10)),       // different month, excluded
    tx(5000, payID, day(2026, 6, 25), .income),
]

// txnsInPeriod: month of June 2026 keeps the four June rows, drops May
let june = txnsInPeriod(sample, period: .month, containing: day(2026, 6, 1), calendar: cal)
assert(june.count == 4)

// categoryTotals: expense only, descending by total
let totals = categoryTotals(june, type: .expense)
assert(totals.count == 2)
assert(totals[0].categoryID == foodID && totals[0].total == 150)
assert(totals[1].categoryID == rideID && totals[1].total == 30)

// income is separate
let inc = categoryTotals(june, type: .income)
assert(inc.count == 1 && inc[0].total == 5000)

// waffleCounts: always sums to exactly 100, proportional
let cells = waffleCounts([Decimal(150), Decimal(30)])
assert(cells.reduce(0, +) == 100)
assert(cells[0] == 83 && cells[1] == 17)   // 150/180=83.3 -> 83, 30/180=16.7 -> 17

// waffleCounts with no spend -> all zero, no crash
assert(waffleCounts([Decimal(0), Decimal(0)]) == [0, 0])

print("all money tests passed")
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swiftc Shared/DayMath.swift Shared/Money.swift tests/main.swift -o /tmp/daydelta_test && /tmp/daydelta_test`
Expected: FAIL — compile error, `cannot find 'txnsInPeriod' in scope` (and the other functions).

- [ ] **Step 3: Implement the functions**

Append to `Shared/Money.swift`:

```swift
// MARK: - Stats

enum StatPeriod: String, CaseIterable {
    case week, month, year

    var granularity: Calendar.Component {
        switch self {
        case .week:  return .weekOfYear
        case .month: return .month
        case .year:  return .year
        }
    }

    var label: String {
        switch self {
        case .week:  return "Week"
        case .month: return "Month"
        case .year:  return "Year"
        }
    }
}

/// Txns falling in the same week/month/year as `ref`.
func txnsInPeriod(_ all: [Txn], period: StatPeriod, containing ref: Date,
                  calendar: Calendar = .current) -> [Txn] {
    all.filter { calendar.isDate($0.date, equalTo: ref, toGranularity: period.granularity) }
}

/// Total per category for one txn type, highest first.
func categoryTotals(_ txns: [Txn], type: TxnType) -> [(categoryID: UUID, total: Decimal)] {
    var sums: [UUID: Decimal] = [:]
    for t in txns where t.type == type {
        sums[t.categoryID, default: 0] += t.amount
    }
    return sums.map { (categoryID: $0.key, total: $0.value) }
        .sorted { $0.total > $1.total }
}

/// Distribute `cells` across `totals` by proportion using largest-remainder, so
/// the result always sums to exactly `cells`. Aligned to the input order.
func waffleCounts(_ totals: [Decimal], cells: Int = 100) -> [Int] {
    let sum = totals.reduce(0, +)
    guard sum > 0 else { return totals.map { _ in 0 } }
    let raw = totals.map { NSDecimalNumber(decimal: $0 / sum).doubleValue * Double(cells) }
    var floors = raw.map { Int($0) }
    var remainder = cells - floors.reduce(0, +)
    let order = raw.enumerated()
        .sorted { ($0.element - Double(Int($0.element))) > ($1.element - Double(Int($1.element))) }
        .map { $0.offset }
    var i = 0
    while remainder > 0, i < order.count {
        floors[order[i]] += 1
        remainder -= 1
        i += 1
    }
    return floors
}

/// Locale-formatted currency string, e.g. "NT$150.00".
func formatMoney(_ amount: Decimal) -> String {
    let code = Locale.current.currency?.identifier ?? "USD"
    return amount.formatted(.currency(code: code))
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swiftc Shared/DayMath.swift Shared/Money.swift tests/main.swift -o /tmp/daydelta_test && /tmp/daydelta_test`
Expected: PASS — prints both `all DayMath tests passed` and `all money tests passed`.

- [ ] **Step 5: Commit**

```bash
git add Shared/Money.swift tests/main.swift
git commit -m "feat: ledger stat functions (period, totals, waffle) with tests"
```

---

## Task 3: Transaction edit sheet

**Files:**
- Create: `DayDelta/TxnEditView.swift`

- [ ] **Step 1: Create the view**

Create `DayDelta/TxnEditView.swift`:

```swift
import SwiftUI

/// Add/edit one transaction. Mirrors EventEditView's style (monospaced, dark).
struct TxnEditView: View {
    let txn: Txn?
    let categories: [Category]
    let onSave: (Txn) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var type: TxnType
    @State private var amount: Decimal?
    @State private var categoryID: UUID?
    @State private var date: Date
    @State private var note: String
    @State private var eventID: UUID?

    private let events = EventStore.load()

    init(txn: Txn?, categories: [Category], onSave: @escaping (Txn) -> Void) {
        self.txn = txn
        self.categories = categories
        self.onSave = onSave
        _type = State(initialValue: txn?.type ?? .expense)
        _amount = State(initialValue: txn?.amount)
        _categoryID = State(initialValue: txn?.categoryID)
        _date = State(initialValue: txn?.date ?? Date())
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
                    Picker("Category", selection: $categoryID) {
                        ForEach(typeCategories) { c in
                            Text(c.name).tag(Optional(c.id))
                        }
                    }
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
```

- [ ] **Step 2: Commit**

```bash
git add DayDelta/TxnEditView.swift
git commit -m "feat: transaction add/edit sheet"
```

> Compilation of the view files is verified together when the TabView is wired (Task 7) by building in Xcode. There is no standalone swiftc path for SwiftUI views.

---

## Task 4: Category manager

**Files:**
- Create: `DayDelta/CategoryManagerView.swift`

- [ ] **Step 1: Create the view**

Create `DayDelta/CategoryManagerView.swift`:

```swift
import SwiftUI

/// Add / rename / recolor / delete categories. Built-ins can't be deleted.
struct CategoryManagerView: View {
    @Binding var categories: [Category]

    @State private var editing: Category?
    @State private var adding = false

    private let colors = ["#4F9DFF", "#A855F7", "#F59E0B", "#22C55E",
                          "#EF4444", "#14B8A6", "#EC4899", "#9CA3AF"]

    var body: some View {
        List {
            ForEach(TxnType.allCases, id: \.self) { type in
                Section(type == .expense ? "Expense" : "Income") {
                    ForEach(categories.filter { $0.type == type }) { c in
                        Button { editing = c } label: { row(c) }
                            .buttonStyle(.plain)
                    }
                    .onDelete { offsets in delete(type: type, offsets: offsets) }
                    Button {
                        editing = Category(name: "", type: type, icon: nil,
                                           colorHex: colors[0])
                        adding = true
                    } label: {
                        Label("Add category", systemImage: "plus")
                    }
                }
            }
        }
        .font(.system(.body, design: .monospaced))
        .scrollContentBackground(.hidden)
        .background(Color.black)
        .navigationTitle("Categories")
        .sheet(item: $editing) { c in
            editSheet(c)
        }
    }

    private func row(_ c: Category) -> some View {
        HStack {
            Circle().fill(Color(hex: c.colorHex)).frame(width: 14, height: 14)
            Text(c.name.isEmpty ? "(unnamed)" : c.name)
            Spacer()
            if c.builtin { Text("built-in").foregroundStyle(.gray).font(.caption) }
        }
    }

    @ViewBuilder
    private func editSheet(_ original: Category) -> some View {
        CategoryEditSheet(category: original, colors: colors) { saved in
            if let i = categories.firstIndex(where: { $0.id == saved.id }) {
                categories[i] = saved
            } else {
                categories.append(saved)
            }
            editing = nil
            adding = false
        }
    }

    /// Only non-builtin categories delete; builtins silently skip.
    private func delete(type: TxnType, offsets: IndexSet) {
        let inType = categories.filter { $0.type == type }
        let ids = offsets.map { inType[$0] }.filter { !$0.builtin }.map { $0.id }
        categories.removeAll { ids.contains($0.id) }
    }
}

/// The per-category editor (name + color).
private struct CategoryEditSheet: View {
    @State var category: Category
    let colors: [String]
    let onSave: (Category) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $category.name)
                Section("Color") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 40))], spacing: 12) {
                        ForEach(colors, id: \.self) { hex in
                            Circle()
                                .fill(Color(hex: hex))
                                .frame(width: 32, height: 32)
                                .overlay(Circle().strokeBorder(
                                    category.colorHex == hex ? Color.white : .clear, lineWidth: 2))
                                .onTapGesture { category.colorHex = hex }
                        }
                    }
                }
                Section("Icon") { IconPicker(selection: $category.icon) }
            }
            .font(.system(.body, design: .monospaced))
            .scrollContentBackground(.hidden)
            .background(Color.black)
            .navigationTitle(category.name.isEmpty ? "New category" : category.name)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let n = category.name.trimmingCharacters(in: .whitespaces)
                        guard !n.isEmpty else { return }
                        category.name = n
                        onSave(category)
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

- [ ] **Step 2: Commit**

```bash
git add DayDelta/CategoryManagerView.swift
git commit -m "feat: category manager (add/rename/recolor/delete)"
```

---

## Task 5: Ledger tab container + 明細 page

**Files:**
- Create: `DayDelta/LedgerView.swift`

- [ ] **Step 1: Create the view and the `Color(hex:)` helper**

Create `DayDelta/LedgerView.swift`:

```swift
import SwiftUI

/// "#RRGGBB" -> Color. Falls back to gray on a malformed string.
extension Color {
    init(hex: String) {
        let s = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        guard s.count == 6, let v = UInt64(s, radix: 16) else { self = .gray; return }
        self = Color(
            red: Double((v >> 16) & 0xFF) / 255,
            green: Double((v >> 8) & 0xFF) / 255,
            blue: Double(v & 0xFF) / 255)
    }
}

/// The 記帳 tab: a segmented switch between the 明細 (ledger) and 統計 (stats)
/// sub-pages, owning the shared txn/category state.
struct LedgerView: View {
    @State private var txns: [Txn] = TxnStore.load()
    @State private var categories: [Category] = CategoryStore.load()
    @State private var page = 0
    @State private var editingTxn: Txn?
    @State private var addingTxn = false
    @State private var managingCategories = false

    var body: some View {
        NavigationStack {
            Group {
                if page == 0 {
                    ledgerList
                } else {
                    StatsView(txns: txns, categories: categories)
                }
            }
            .background(Color.black)
            .navigationTitle("記帳")
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Picker("", selection: $page) {
                        Text("明細").tag(0)
                        Text("統計").tag(1)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 180)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button { addingTxn = true } label: { Label("Add", systemImage: "plus") }
                        Button { managingCategories = true } label: {
                            Label("Categories", systemImage: "tag")
                        }
                    } label: { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $addingTxn) {
                TxnEditView(txn: nil, categories: categories) { saved in
                    txns.append(saved); persist()
                }
            }
            .sheet(item: $editingTxn) { t in
                TxnEditView(txn: t, categories: categories) { saved in
                    if let i = txns.firstIndex(where: { $0.id == saved.id }) { txns[i] = saved }
                    persist()
                }
            }
            .sheet(isPresented: $managingCategories) {
                NavigationStack { CategoryManagerView(categories: $categories) }
                    .preferredColorScheme(.dark).tint(.white)
                    .onDisappear { CategoryStore.save(categories) }
            }
        }
        // Pick up changes made by Backup import in the other tab.
        .onAppear {
            txns = TxnStore.load()
            categories = CategoryStore.load()
        }
    }

    // MARK: 明細

    private var ledgerList: some View {
        Group {
            if txns.isEmpty {
                ContentUnavailableView("No records", systemImage: "list.bullet",
                    description: Text("Tap + to add income or expense."))
            } else {
                List {
                    summarySection
                    ForEach(dayGroups, id: \.0) { day, rows in
                        Section(dateLabel(day)) {
                            ForEach(rows) { t in
                                row(t)
                                    .listRowBackground(Color.black)
                                    .contentShape(Rectangle())
                                    .onTapGesture { editingTxn = t }
                            }
                            .onDelete { deleteInDay(day: day, offsets: $0) }
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
    }

    private var summarySection: some View {
        let month = txnsInPeriod(txns, period: .month, containing: Date())
        let income = categoryTotals(month, type: .income).reduce(Decimal(0)) { $0 + $1.total }
        let expense = categoryTotals(month, type: .expense).reduce(Decimal(0)) { $0 + $1.total }
        return Section("This month") {
            HStack {
                summaryCell("Income", income, .green)
                summaryCell("Expense", expense, .red)
                summaryCell("Net", income - expense, .white)
            }
            .listRowBackground(Color.black)
        }
    }

    private func summaryCell(_ label: String, _ value: Decimal, _ color: Color) -> some View {
        VStack(spacing: 2) {
            Text(label).font(.caption).foregroundStyle(.gray)
            Text(formatMoney(value)).font(.system(.callout, design: .monospaced))
                .foregroundStyle(color).minimumScaleFactor(0.6).lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }

    private func row(_ t: Txn) -> some View {
        let c = categories.first { $0.id == t.categoryID }
        return HStack {
            Circle().fill(Color(hex: c?.colorHex ?? "#9CA3AF")).frame(width: 12, height: 12)
            VStack(alignment: .leading) {
                Text(c?.name ?? "—").font(.system(.body, design: .monospaced))
                if let note = t.note {
                    Text(note).font(.caption).foregroundStyle(.gray)
                }
            }
            Spacer()
            Text((t.type == .expense ? "-" : "+") + formatMoney(t.amount))
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(t.type == .expense ? .red : .green)
        }
    }

    /// Txns grouped by start-of-day, newest day first.
    private var dayGroups: [(Date, [Txn])] {
        let cal = Calendar.current
        let grouped = Dictionary(grouping: txns) { cal.startOfDay(for: $0.date) }
        return grouped.keys.sorted(by: >).map { ($0, grouped[$0]!.sorted { $0.date > $1.date }) }
    }

    private func deleteInDay(day: Date, offsets: IndexSet) {
        let cal = Calendar.current
        let rows = (dayGroups.first { $0.0 == day }?.1) ?? []
        let ids = offsets.map { rows[$0].id }
        txns.removeAll { ids.contains($0.id) }
        persist()
        _ = cal
    }

    private func persist() { TxnStore.save(txns) }
}
```

- [ ] **Step 2: Commit**

```bash
git add DayDelta/LedgerView.swift
git commit -m "feat: ledger tab container and 明細 list"
```

---

## Task 6: 統計 page (donut + breakdown + waffle)

**Files:**
- Create: `DayDelta/StatsView.swift`

- [ ] **Step 1: Create the view**

Create `DayDelta/StatsView.swift`:

```swift
import SwiftUI
import Charts

/// 統計 page: period + type toggles, donut, breakdown list, waffle.
struct StatsView: View {
    let txns: [Txn]
    let categories: [Category]

    @State private var period: StatPeriod = .month
    @State private var type: TxnType = .expense

    private func color(_ id: UUID) -> Color {
        Color(hex: categories.first { $0.id == id }?.colorHex ?? "#9CA3AF")
    }
    private func name(_ id: UUID) -> String {
        categories.first { $0.id == id }?.name ?? "—"
    }

    /// (categoryID, total) for the selected period + type, highest first.
    private var breakdown: [(categoryID: UUID, total: Decimal)] {
        let inPeriod = txnsInPeriod(txns, period: period, containing: Date())
        return categoryTotals(inPeriod, type: type)
    }

    private var total: Decimal { breakdown.reduce(0) { $0 + $1.total } }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Picker("Period", selection: $period) {
                    ForEach(StatPeriod.allCases, id: \.self) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)

                Picker("Type", selection: $type) {
                    Text("Expense").tag(TxnType.expense)
                    Text("Income").tag(TxnType.income)
                }
                .pickerStyle(.segmented)

                if breakdown.isEmpty {
                    ContentUnavailableView("No data", systemImage: "chart.pie",
                        description: Text("Nothing recorded in this period."))
                        .padding(.top, 40)
                } else {
                    donut
                    breakdownList
                    waffle
                }
            }
            .padding()
        }
        .scrollContentBackground(.hidden)
        .background(Color.black)
    }

    // MARK: Donut

    private var donut: some View {
        Chart(breakdown, id: \.categoryID) { item in
            SectorMark(
                angle: .value("Total", NSDecimalNumber(decimal: item.total).doubleValue),
                innerRadius: .ratio(0.62),
                angularInset: 1.5
            )
            .cornerRadius(3)
            .foregroundStyle(color(item.categoryID))
        }
        .frame(height: 220)
        .chartBackground { _ in
            VStack {
                Text(type == .expense ? "Expense" : "Income")
                    .font(.caption).foregroundStyle(.gray)
                Text(formatMoney(total))
                    .font(.system(.title2, design: .monospaced)).bold()
                    .foregroundStyle(.white).minimumScaleFactor(0.5).lineLimit(1)
            }
        }
    }

    // MARK: Breakdown list

    private var breakdownList: some View {
        VStack(spacing: 10) {
            ForEach(breakdown, id: \.categoryID) { item in
                HStack {
                    Circle().fill(color(item.categoryID)).frame(width: 12, height: 12)
                    Text(name(item.categoryID))
                    Spacer()
                    Text(formatMoney(item.total)).foregroundStyle(.gray)
                    Text(percent(item.total)).frame(width: 52, alignment: .trailing).bold()
                }
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.white)
            }
        }
    }

    private func percent(_ v: Decimal) -> String {
        guard total > 0 else { return "0%" }
        let p = NSDecimalNumber(decimal: v / total).doubleValue * 100
        return "\(Int(p.rounded()))%"
    }

    // MARK: Waffle

    private var waffle: some View {
        let counts = waffleCounts(breakdown.map { $0.total })
        // Expand into 100 colored cells by category order.
        let cellColors: [Color] = zip(breakdown, counts).flatMap { item, n in
            Array(repeating: color(item.categoryID), count: n)
        }
        let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 10)
        return LazyVGrid(columns: columns, spacing: 4) {
            ForEach(0..<100, id: \.self) { i in
                RoundedRectangle(cornerRadius: 3)
                    .fill(i < cellColors.count ? cellColors[i] : Color.white.opacity(0.08))
                    .aspectRatio(1, contentMode: .fit)
            }
        }
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add DayDelta/StatsView.swift
git commit -m "feat: 統計 page with donut, breakdown, and waffle"
```

---

## Task 7: Wire the TabView

**Files:**
- Modify: `DayDelta/DayDeltaApp.swift`

- [ ] **Step 1: Replace the root with a TabView**

Replace the entire body of `DayDelta/DayDeltaApp.swift`:

```swift
import SwiftUI

@main
struct DayDeltaApp: App {
    var body: some Scene {
        WindowGroup {
            TabView {
                ContentView()
                    .tabItem { Label("Days", systemImage: "calendar") }
                LedgerView()
                    .tabItem { Label("記帳", systemImage: "dollarsign.circle") }
            }
            .preferredColorScheme(.dark)
            .tint(.white)
        }
    }
}
```

- [ ] **Step 2: Build in Xcode to verify everything compiles together**

Run (or build in Xcode — the project uses XcodeGen; regenerate if needed):
```bash
xcodegen generate
xcodebuild -scheme DayDelta -destination 'generic/platform=iOS Simulator' build CODE_SIGNING_ALLOWED=NO
```
Expected: BUILD SUCCEEDED. The new files are under `DayDelta/` and `Shared/`, both already in the `DayDelta` target's `sources`, so no `project.yml` change is needed.

- [ ] **Step 3: Commit**

```bash
git add DayDelta/DayDeltaApp.swift
git commit -m "feat: add 記帳 tab via TabView root"
```

---

## Task 8: Spending total on the event detail

**Files:**
- Modify: `DayDelta/MemoryDetailView.swift`

- [ ] **Step 1: Add the spending line**

In `DayDelta/MemoryDetailView.swift`, inside the `VStack(alignment: .leading, spacing: 8)`, after the note block (`if let note = event.note { ... }`), add:

```swift
                let spent = TxnStore.load()
                    .filter { $0.eventID == event.id && $0.type == .expense }
                    .reduce(Decimal(0)) { $0 + $1.amount }
                if spent > 0 {
                    Text("這趟花費 " + formatMoney(spent))
                        .font(.system(.callout, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.85))
                }
```

> `TxnStore.load()` is a cheap `UserDefaults` read; computing it inline in `body` is fine for a single detail screen. ponytail: no need to thread ledger state into this view.

- [ ] **Step 2: Build to verify**

Run: `xcodebuild -scheme DayDelta -destination 'generic/platform=iOS Simulator' build CODE_SIGNING_ALLOWED=NO`
Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add DayDelta/MemoryDetailView.swift
git commit -m "feat: show per-event spending total on detail view"
```

---

## Task 9: Backup covers txns + categories (back-compatible)

**Files:**
- Modify: `DayDelta/Backup.swift`
- Modify: `DayDelta/ContentView.swift`

- [ ] **Step 1: Add the backup wrapper type**

Append to `DayDelta/Backup.swift`:

```swift
/// The full backup payload. Replaces the old bare `[Event]` JSON; `handleImport`
/// still falls back to decoding a bare array so old backups keep working.
struct BackupData: Codable {
    var events: [Event]
    var txns: [Txn]
    var categories: [Category]
}
```

- [ ] **Step 2: Update export in ContentView**

In `DayDelta/ContentView.swift`, replace `exportData()`:

```swift
    private func exportData() -> Data {
        let payload = BackupData(events: events,
                                 txns: TxnStore.load(),
                                 categories: CategoryStore.load())
        return (try? JSONEncoder().encode(payload)) ?? Data()
    }
```

- [ ] **Step 3: Update import in ContentView**

Replace `handleImport(_:)`:

```swift
    /// Merge an imported backup. Accepts the new wrapper format and falls back to
    /// a legacy bare `[Event]` array. Upserts every record by id.
    private func handleImport(_ result: Result<URL, Error>) {
        guard case .success(let url) = result else { return }
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url) else { return }

        if let backup = try? JSONDecoder().decode(BackupData.self, from: data) {
            merge(backup.events)
            mergeTxns(backup.txns)
            mergeCategories(backup.categories)
        } else if let legacy = try? JSONDecoder().decode([Event].self, from: data) {
            merge(legacy)
        }
        persist()
    }

    private func merge(_ imported: [Event]) {
        for e in imported {
            if let i = events.firstIndex(where: { $0.id == e.id }) { events[i] = e }
            else { events.append(e) }
        }
    }

    private func mergeTxns(_ imported: [Txn]) {
        var txns = TxnStore.load()
        for t in imported {
            if let i = txns.firstIndex(where: { $0.id == t.id }) { txns[i] = t }
            else { txns.append(t) }
        }
        TxnStore.save(txns)
    }

    private func mergeCategories(_ imported: [Category]) {
        var cats = CategoryStore.load()
        for c in imported {
            if let i = cats.firstIndex(where: { $0.id == c.id }) { cats[i] = c }
            else { cats.append(c) }
        }
        CategoryStore.save(cats)
    }
```

> The ledger tab reloads from the stores in its `.onAppear` (Task 5), so an import done from the Days tab shows up when the user switches to 記帳.

- [ ] **Step 4: Build to verify**

Run: `xcodebuild -scheme DayDelta -destination 'generic/platform=iOS Simulator' build CODE_SIGNING_ALLOWED=NO`
Expected: BUILD SUCCEEDED.

- [ ] **Step 5: Commit**

```bash
git add DayDelta/Backup.swift DayDelta/ContentView.swift
git commit -m "feat: backup export/import covers txns and categories"
```

---

## Self-review notes

- **Spec coverage:** income+expense (Task 1 `TxnType`), built-in+custom categories (Task 1 seed, Task 4 manager), two sub-pages (Task 5 Picker), donut+waffle (Task 6), event linking (Task 3 picker + Task 8 total), backup (Task 9), Decimal money + period/total/waffle tests (Task 2). No sunburst/budget/multi-currency — matches "out of scope".
- **Type consistency:** `txnsInPeriod`, `categoryTotals`, `waffleCounts`, `formatMoney`, `Color(hex:)`, `TxnStore`/`CategoryStore`, `BackupData` are referenced with the same signatures everywhere they appear.
- **Deferred:** `sunburst`, budget page, multi-currency — intentionally not built.
