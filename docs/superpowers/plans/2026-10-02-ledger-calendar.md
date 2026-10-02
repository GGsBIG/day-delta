# Ledger Calendar Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the Money tab's Ledger sub-page with a month calendar that shows every day; tapping a day lists that day's transactions inline.

**Architecture:** Pure calendar/date logic goes in `Shared/Money.swift` (Foundation-only, unit-tested via swiftc). A new focused `MonthCalendarView` renders the header + grid. `LedgerView`'s Ledger page becomes calendar + selected-day list. `TxnEditView` gains an optional default date.

**Tech Stack:** Swift 5, SwiftUI, iOS 17+. No new dependencies.

**Spec:** `docs/superpowers/specs/2026-10-02-ledger-calendar-design.md`

**Build/test commands:**
- Logic tests: `swiftc Shared/DayMath.swift Shared/Money.swift tests/main.swift -o /tmp/t && /tmp/t`
- Full build: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -scheme DayDelta -destination 'generic/platform=iOS Simulator' build CODE_SIGNING_ALLOWED=NO` (run `xcodegen generate` first if `.xcodeproj` is missing)

---

## File Structure

- Modify `Shared/Money.swift` — add `daysInMonth`, `leadingBlanks`, `txnsOn`, `dominantCategoryID`, `addMonths`.
- Modify `tests/main.swift` — asserts for the five functions.
- Create `DayDelta/MonthCalendar.swift` — `MonthCalendarView` (header + weekday row + day grid).
- Modify `DayDelta/TxnEditView.swift` — optional `defaultDate` param.
- Modify `DayDelta/LedgerView.swift` — Ledger page becomes calendar + selected-day list; remove the old summary/running-list code.

---

## Task 1: Calendar date logic (TDD)

**Files:**
- Modify: `Shared/Money.swift`
- Test: `tests/main.swift`

- [ ] **Step 1: Write the failing tests**

In `tests/main.swift`, find the line `print("all money tests passed")` and insert this block immediately BEFORE it:

```swift
// ---- Calendar logic ----

// daysInMonth: October 2026 has 31 days, first Oct 1, last Oct 31
let oct = daysInMonth(containing: day(2026, 10, 15), calendar: cal)
assert(oct.count == 31)
assert(ymd(oct.first!) == (2026, 10, 1))
assert(ymd(oct.last!) == (2026, 10, 31))

// leadingBlanks: Oct 1 2026 is a Thursday (weekday 5, Sun=1). With a Sunday-first
// calendar, that's 4 blank cells (Sun..Wed) before day 1.
var sunFirst = cal
sunFirst.firstWeekday = 1
assert(leadingBlanks(forMonthContaining: day(2026, 10, 10), calendar: sunFirst) == 4)
// With a Monday-first calendar, Thursday is offset 3 (Mon,Tue,Wed).
var monFirst = cal
monFirst.firstWeekday = 2
assert(leadingBlanks(forMonthContaining: day(2026, 10, 10), calendar: monFirst) == 3)

// txnsOn: only the txns on that calendar day
let calTxns = [
    tx(100, foodID, day(2026, 10, 2)),
    tx(50,  rideID, day(2026, 10, 2)),
    tx(999, foodID, day(2026, 10, 3)),
]
assert(txnsOn(calTxns, day: day(2026, 10, 2), calendar: cal).count == 2)
assert(txnsOn(calTxns, day: day(2026, 10, 5), calendar: cal).isEmpty)

// dominantCategoryID: category of the single largest-amount txn
assert(dominantCategoryID(calTxns) == foodID)   // 999 is the max
assert(dominantCategoryID([]) == nil)

// addMonths: forward across year end and backward across year start
assert(ymd(addMonths(1, to: day(2026, 10, 15), calendar: cal)) == (2026, 11, 15))
assert(ymd(addMonths(-1, to: day(2026, 1, 10), calendar: cal)) == (2025, 12, 10))
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swiftc Shared/DayMath.swift Shared/Money.swift tests/main.swift -o /tmp/t && /tmp/t`
Expected: FAIL — `cannot find 'daysInMonth' in scope` (and the others).

- [ ] **Step 3: Implement the functions**

Append to `Shared/Money.swift`:

```swift
// MARK: - Calendar

/// Start-of-day Date for every day in the month containing `ref`.
func daysInMonth(containing ref: Date, calendar: Calendar = .current) -> [Date] {
    guard let range = calendar.range(of: .day, in: .month, for: ref),
          let first = calendar.date(from: calendar.dateComponents([.year, .month], from: ref))
    else { return [] }
    return range.compactMap { calendar.date(byAdding: .day, value: $0 - 1, to: first) }
}

/// Number of empty leading cells before day 1, honoring `calendar.firstWeekday`.
func leadingBlanks(forMonthContaining ref: Date, calendar: Calendar = .current) -> Int {
    guard let first = calendar.date(from: calendar.dateComponents([.year, .month], from: ref))
    else { return 0 }
    let weekday = calendar.component(.weekday, from: first)
    return (weekday - calendar.firstWeekday + 7) % 7
}

/// Txns whose date is the same calendar day as `day`.
func txnsOn(_ all: [Txn], day: Date, calendar: Calendar = .current) -> [Txn] {
    all.filter { calendar.isDate($0.date, inSameDayAs: day) }
}

/// Category id of the single largest-amount txn (for the day's dot color).
func dominantCategoryID(_ txns: [Txn]) -> UUID? {
    txns.max { $0.amount < $1.amount }?.categoryID
}

/// `ref` shifted by `months`, normalized to start of day.
func addMonths(_ months: Int, to ref: Date, calendar: Calendar = .current) -> Date {
    let d = calendar.date(byAdding: .month, value: months, to: ref) ?? ref
    return calendar.startOfDay(for: d)
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swiftc Shared/DayMath.swift Shared/Money.swift tests/main.swift -o /tmp/t && /tmp/t`
Expected: PASS — prints `all DayMath tests passed` and `all money tests passed`.

- [ ] **Step 5: Commit**

```bash
git add Shared/Money.swift tests/main.swift
git commit -m "feat: calendar date logic for ledger month view"
```

---

## Task 2: TxnEditView default date

**Files:**
- Modify: `DayDelta/TxnEditView.swift`

- [ ] **Step 1: Add the `defaultDate` parameter**

In `DayDelta/TxnEditView.swift`, change the stored properties and initializer.

Find:
```swift
    let txn: Txn?
    let categories: [Category]
    let onSave: (Txn) -> Void
```
Replace with:
```swift
    let txn: Txn?
    let categories: [Category]
    var defaultDate: Date? = nil
    let onSave: (Txn) -> Void
```

Find:
```swift
    init(txn: Txn?, categories: [Category], onSave: @escaping (Txn) -> Void) {
        self.txn = txn
        self.categories = categories
        self.onSave = onSave
        _type = State(initialValue: txn?.type ?? .expense)
        _amount = State(initialValue: txn?.amount)
        _categoryID = State(initialValue: txn?.categoryID)
        _date = State(initialValue: txn?.date ?? Date())
```
Replace with:
```swift
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
```

- [ ] **Step 2: Verify the build**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -scheme DayDelta -destination 'generic/platform=iOS Simulator' build CODE_SIGNING_ALLOWED=NO 2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED"`
Expected: `** BUILD SUCCEEDED **` (existing call sites still compile — the new param defaults to nil).

- [ ] **Step 3: Commit**

```bash
git add DayDelta/TxnEditView.swift
git commit -m "feat: optional default date for new transactions"
```

---

## Task 3: MonthCalendarView

**Files:**
- Create: `DayDelta/MonthCalendar.swift`

Depends on: `Color(hex:)` (defined in `LedgerView.swift`), and the Task 1 functions.

- [ ] **Step 1: Create the view**

Create `DayDelta/MonthCalendar.swift` with EXACTLY this content:

```swift
import SwiftUI

/// Month header + weekday row + day grid for the Ledger. Days with any txn show
/// a dot colored by that day's largest-amount category. Today is ringed; the
/// selected day is filled.
struct MonthCalendarView: View {
    let monthAnchor: Date
    let txns: [Txn]
    let categories: [Category]
    @Binding var selectedDay: Date
    let onPrevMonth: () -> Void
    let onNextMonth: () -> Void

    private let cal = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    var body: some View {
        VStack(spacing: 12) {
            header
            weekdayRow
            grid
        }
        .padding(.horizontal, 4)
    }

    private var header: some View {
        HStack {
            Button(action: onPrevMonth) { Image(systemName: "chevron.left") }
            Spacer()
            Text(monthTitle)
                .font(.system(.headline, design: .monospaced))
            Spacer()
            Button(action: onNextMonth) { Image(systemName: "chevron.right") }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 8)
    }

    private var monthTitle: String {
        let f = DateFormatter()
        f.calendar = cal
        f.locale = .current
        f.dateFormat = "LLLL yyyy"
        return f.string(from: monthAnchor)
    }

    private var weekdayRow: some View {
        let symbols = orderedWeekdaySymbols()
        return LazyVGrid(columns: columns, spacing: 4) {
            ForEach(symbols, id: \.self) { s in
                Text(s).font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.gray)
            }
        }
    }

    /// Very-short weekday symbols rotated to start at `calendar.firstWeekday`.
    private func orderedWeekdaySymbols() -> [String] {
        let base = cal.veryShortStandaloneWeekdaySymbols   // index 0 = Sunday
        let start = cal.firstWeekday - 1
        return (0..<7).map { base[($0 + start) % 7] }
    }

    private var grid: some View {
        LazyVGrid(columns: columns, spacing: 6) {
            ForEach(0..<leadingBlanks(forMonthContaining: monthAnchor, calendar: cal), id: \.self) { _ in
                Color.clear.frame(height: 40)
            }
            ForEach(daysInMonth(containing: monthAnchor, calendar: cal), id: \.self) { day in
                dayCell(day)
            }
        }
    }

    private func dayCell(_ day: Date) -> some View {
        let dayTxns = txnsOn(txns, day: day, calendar: cal)
        let isSelected = cal.isDate(day, inSameDayAs: selectedDay)
        let isToday = cal.isDateInToday(day)
        let dotColor = dominantCategoryID(dayTxns)
            .flatMap { id in categories.first { $0.id == id } }
            .map { Color(hex: $0.colorHex) }
        return Button {
            selectedDay = cal.startOfDay(for: day)
        } label: {
            VStack(spacing: 3) {
                Text("\(cal.component(.day, from: day))")
                    .font(.system(.callout, design: .monospaced))
                    .foregroundStyle(isSelected ? .black : .white)
                Circle()
                    .fill(dotColor ?? .clear)
                    .frame(width: 5, height: 5)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 40)
            .background(isSelected ? Color.white : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(isToday && !isSelected ? Color.white.opacity(0.5) : .clear,
                                  lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add DayDelta/MonthCalendar.swift
git commit -m "feat: month calendar grid view"
```

> SwiftUI views have no standalone compile check; they build with the app in Task 4. Ignore per-file SourceKit warnings about missing types.

---

## Task 4: Rewrite the Ledger page in LedgerView

**Files:**
- Modify: `DayDelta/LedgerView.swift`

- [ ] **Step 1: Replace the state declarations**

In `DayDelta/LedgerView.swift`, find:
```swift
    @State private var txns: [Txn] = TxnStore.load()
    @State private var categories: [Category] = CategoryStore.load()
    @State private var page = 0
    @State private var editingTxn: Txn?
    @State private var addingTxn = false
    @State private var managingCategories = false
```
Replace with:
```swift
    @State private var txns: [Txn] = TxnStore.load()
    @State private var categories: [Category] = CategoryStore.load()
    @State private var page = 0
    @State private var editingTxn: Txn?
    @State private var addingTxn = false
    @State private var managingCategories = false
    @State private var monthAnchor = Date()
    @State private var selectedDay = Calendar.current.startOfDay(for: Date())
```

- [ ] **Step 2: Pass the default date into the add sheet**

Find:
```swift
            .sheet(isPresented: $addingTxn) {
                TxnEditView(txn: nil, categories: categories) { saved in
                    txns.append(saved); persist()
                }
            }
```
Replace with:
```swift
            .sheet(isPresented: $addingTxn) {
                TxnEditView(txn: nil, categories: categories, defaultDate: selectedDay) { saved in
                    txns.append(saved); persist()
                }
            }
```

- [ ] **Step 3: Replace the `ledgerList` property**

`row(_:)` and `persist()` must be KEPT. In the current file `row(_:)` sits between
`summaryCell` and `dayGroups`, so do these as separate surgical edits (Steps 3–6),
not one big span replace.

Replace the whole `ledgerList` property. Find:
```swift
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
```
Replace with:
```swift
    private var ledgerList: some View {
        ScrollView {
            VStack(spacing: 16) {
                MonthCalendarView(
                    monthAnchor: monthAnchor,
                    txns: txns,
                    categories: categories,
                    selectedDay: $selectedDay,
                    onPrevMonth: { changeMonth(-1) },
                    onNextMonth: { changeMonth(1) }
                )
                .padding(.top, 8)

                selectedDayList
            }
            .padding(.horizontal)
        }
        .scrollContentBackground(.hidden)
    }

    @ViewBuilder
    private var selectedDayList: some View {
        let rows = txnsOn(txns, day: selectedDay).sorted { $0.date > $1.date }
        VStack(alignment: .leading, spacing: 10) {
            Text(dateLabel(selectedDay))
                .font(.system(.subheadline, design: .monospaced))
                .foregroundStyle(.gray)
            if rows.isEmpty {
                Text("No transactions")
                    .font(.system(.callout, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 12)
            } else {
                ForEach(rows) { t in
                    row(t)
                        .contentShape(Rectangle())
                        .onTapGesture { editingTxn = t }
                        .contextMenu {
                            Button(role: .destructive) { delete(t) } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func changeMonth(_ delta: Int) {
        monthAnchor = addMonths(delta, to: monthAnchor)
    }

    /// Delete a selected-day transaction by id.
    private func delete(_ t: Txn) {
        txns.removeAll { $0.id == t.id }
        persist()
    }
```

- [ ] **Step 4: Delete `summarySection` and `summaryCell`**

Delete these two whole functions (they are no longer referenced):
```swift
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
```
(Leave `row(_:)`, which follows them, untouched.)

- [ ] **Step 5: Delete `dayGroups` and `deleteInDay`**

Delete these two whole members (replaced by `selectedDayList` / `delete`):
```swift
    /// Txns grouped by start-of-day, newest day first.
    private var dayGroups: [(Date, [Txn])] {
        let cal = Calendar.current
        let grouped = Dictionary(grouping: txns) { cal.startOfDay(for: $0.date) }
        return grouped.keys.sorted(by: >).map { ($0, grouped[$0]!.sorted { $0.date > $1.date }) }
    }

    private func deleteInDay(day: Date, offsets: IndexSet) {
        let rows = (dayGroups.first { $0.0 == day }?.1) ?? []
        let ids = offsets.map { rows[$0].id }
        txns.removeAll { ids.contains($0.id) }
        persist()
    }
```
(`persist()`, which follows, stays.)

- [ ] **Step 6: Verify the build**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -scheme DayDelta -destination 'generic/platform=iOS Simulator' build CODE_SIGNING_ALLOWED=NO 2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED"`
Expected: `** BUILD SUCCEEDED **`.

If the compiler reports `row` as unused in another context or an unused
variable, that is fine; only `error:` lines block. `row(_:)`, `persist()`,
`.onAppear`, the `page` Picker, and the Stats branch remain unchanged and in use.

- [ ] **Step 7: Commit**

```bash
git add DayDelta/LedgerView.swift
git commit -m "feat: ledger month calendar with selected-day list"
```

---

## Task 5: Run it on the simulator

**Files:** none (verification).

- [ ] **Step 1: Build, install, launch**

```bash
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
xcodegen generate
xcodebuild -scheme DayDelta -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/dd-dd build CODE_SIGNING_ALLOWED=NO 2>&1 | grep -E "BUILD SUCCEEDED|BUILD FAILED|error:"
xcrun simctl boot "iPhone 17" 2>/dev/null; open -a Simulator
APP=$(find /tmp/dd-dd/Build/Products -name "DayDelta.app" -maxdepth 3 | head -1)
xcrun simctl install "iPhone 17" "$APP"
xcrun simctl launch "iPhone 17" com.tcsxft.daydelta.app
```

- [ ] **Step 2: Confirm the Ledger shows a month calendar**

Switch to the Money tab, Ledger sub-page. Expected: a month grid with the
current month, today ringed, dots on days with transactions, and today's
transactions (or "No transactions") listed below. Screenshot and inspect.
(If seeding data is needed, reuse the approach from the prior run: encode `[Txn]`
and `[Category]` with a swiftc script and `xcrun simctl spawn "iPhone 17"
defaults write com.tcsxft.daydelta.app <key> -data <hex>`.)

No commit — verification only.

---

## Self-review notes

- **Spec coverage:** calendar every day (Task 1 `daysInMonth` + Task 3 grid);
  colored dot by largest txn (Task 1 `dominantCategoryID` + Task 3 `dayCell`);
  tap-to-select inline list, default today (Task 4 `selectedDay`, `selectedDayList`);
  empty-day placeholder (Task 4); `+` defaults to selected day (Task 2 + Task 4
  Step 2); removed summary/running list (Task 4 Step 3); month navigation (Task 3
  header + Task 4 `changeMonth`); tests (Task 1).
- **Type consistency:** `daysInMonth`, `leadingBlanks`, `txnsOn`, `dominantCategoryID`,
  `addMonths`, `MonthCalendarView(monthAnchor:txns:categories:selectedDay:onPrevMonth:onNextMonth:)`,
  `TxnEditView(txn:categories:defaultDate:onSave:)` are used with matching signatures
  across tasks. `Color(hex:)` and `row(_:)` reused from existing `LedgerView.swift`.
- **Deferred:** week/day modes, swipe-between-months, per-cell totals, heat-map.
