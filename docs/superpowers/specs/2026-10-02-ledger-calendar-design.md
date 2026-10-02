# Ledger Calendar Redesign — Design

**Date:** 2026-10-02
**Status:** Approved, ready for implementation plan

## Goal

Redesign the Money tab's **Ledger** sub-page from a grouped running list (only
days with transactions) into a **month calendar** that shows every day of the
month. Tapping a day shows that day's transactions inline below the grid. The
**Stats** sub-page is unchanged.

## Scope decisions

- Calendar grid showing the complete month, every day drawn (empty days included).
- Each day with any transaction shows a small colored **dot** — color = the
  category of that day's single largest-amount transaction.
- Tap a day → it highlights and its transactions list inline below the grid.
  Default selection is **today**.
- Empty selected day shows a "No transactions" placeholder.
- `+` (add) defaults the new transaction's date to the currently selected day.
- **Removed:** the "This month" Income/Expense/Net summary row, and the old
  `dayGroups` running list.

## Data / pure logic (added to `Shared/Money.swift`, Foundation-only, tested)

```swift
/// Start-of-day Date for every day in the month containing `ref`.
func daysInMonth(containing ref: Date, calendar: Calendar = .current) -> [Date]

/// Count of empty leading cells before day 1, honoring `calendar.firstWeekday`.
func leadingBlanks(forMonthContaining ref: Date, calendar: Calendar = .current) -> Int

/// Txns whose date is the same calendar day as `day`.
func txnsOn(_ all: [Txn], day: Date, calendar: Calendar = .current) -> [Txn]

/// Category id of the single largest-amount txn in the set (for the dot color).
func dominantCategoryID(_ txns: [Txn]) -> UUID?

/// `ref` shifted by `months` (e.g. -1 / +1), normalized to start of day.
func addMonths(_ months: Int, to ref: Date, calendar: Calendar = .current) -> Date
```

Notes:
- `leadingBlanks` = `(weekday(day1) - firstWeekday + 7) % 7`.
- `dominantCategoryID` returns nil for an empty set; ties broken by first max.

## Components

### `DayDelta/MonthCalendar.swift` (new) — `MonthCalendarView`

A focused view: month header + weekday row + day grid.

Inputs:
- `monthAnchor: Date` — any date in the displayed month.
- `txns: [Txn]`, `categories: [Category]` — to place and color dots.
- `@Binding selectedDay: Date` — the highlighted day.
- `onPrevMonth: () -> Void`, `onNextMonth: () -> Void` — header chevrons.

Renders:
- Header: `‹  <MonthName Year>  ›` (chevrons call the callbacks).
- Weekday header row, ordered by `calendar.firstWeekday`.
- `LazyVGrid` 7 columns: `leadingBlanks` empty cells, then one cell per day
  from `daysInMonth`. Each cell shows the day number; a dot below it when
  `txnsOn` is non-empty, filled with `Color(hex:)` of `dominantCategoryID`'s
  category (gray fallback). Today gets a thin ring; `selectedDay` gets a filled
  background. Tapping a day sets `selectedDay`.

### `DayDelta/LedgerView.swift` (modified)

Ledger sub-page becomes:
```
VStack {
    MonthCalendarView(monthAnchor:, txns:, categories:, selectedDay: $selectedDay,
                      onPrevMonth:, onNextMonth:)
    selectedDayList   // txnsOn(selectedDay) using existing row(), or placeholder
}
```
New state: `@State monthAnchor = Date()`, `@State selectedDay = startOfDay(today)`.
Prev/next adjust `monthAnchor` via `addMonths`. Keep `row()`, delete, `persist()`,
`.onAppear` reload. Remove `summarySection`, `summaryCell`, `dayGroups`,
`deleteInDay` (replaced by a selected-day delete), and the old `ledgerList`.
`addingTxn` sheet passes `defaultDate: selectedDay`.

### `DayDelta/TxnEditView.swift` (modified)

Add `var defaultDate: Date? = nil`; when `txn == nil`, initialize the date state
to `defaultDate ?? Date()`. Existing call sites keep working (param defaults nil).

## Testing

Append asserts to `tests/main.swift` for the pure functions:
- `daysInMonth` returns 31 for Oct 2026, first = Oct 1, last = Oct 31.
- `leadingBlanks` for Oct 2026 with a known `firstWeekday` (Oct 1 2026 is a
  Thursday) matches the expected offset.
- `txnsOn` filters to the right day; `dominantCategoryID` picks the largest.
- `addMonths(1, Oct 15)` → Nov; `addMonths(-1, Jan 10)` → Dec prior year.

Run: `swiftc Shared/DayMath.swift Shared/Money.swift tests/main.swift -o /tmp/t && /tmp/t`

## Out of scope

- Week/day calendar modes, swipe-between-months gestures, per-day totals in
  cells (dot only), heat-map coloring.
