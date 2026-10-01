# Expense Tracking (記帳) — Design

**Date:** 2026-10-01
**Status:** Approved, ready for implementation plan

## Goal

Add income/expense tracking to DayDelta. Independent ledger as the primary
feature, with the option to attach a transaction to an existing countdown
`Event` (e.g. spending on a "Japan trip"). Native SwiftUI + Swift Charts only —
no new dependencies. The referenced uiarc.dev React components (donut, waffle,
sunburst) are **visual references only**; they cannot run in this native app.

## Scope decisions

- Income **and** expense, with balance (net).
- Categories: built-in preset set **plus** user-customizable (add/rename/icon/color).
- Two sub-pages under a new "記帳" tab: **明細 (ledger)** and **統計 (stats)**.
- Charts: **donut + waffle** only.
- **Out of scope (YAGNI):** sunburst, budget page, multi-currency.

## Data model

Reuses the existing `Event` pattern: `Codable` structs persisted as JSON in
`UserDefaults`, mirroring `EventStore`.

```swift
enum TxnType: String, Codable { case expense, income }

struct Txn: Codable, Identifiable, Hashable {
    var id = UUID()
    var type: TxnType
    var amount: Decimal        // Decimal, not Double — money must not carry float error
    var categoryID: UUID
    var date: Date
    var note: String?
    var eventID: UUID?         // optional link to a countdown Event
}

struct Category: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var type: TxnType          // income vs expense categories are separate
    var icon: String?          // reuses existing custom-icon mechanism
    var colorHex: String       // drives donut/waffle colors
    var builtin: Bool          // builtins can be renamed, not deleted
}
```

- `TxnStore` and `CategoryStore`: same shape as `EventStore` (`load()`/`save()`,
  JSON in `UserDefaults`), separate keys (`daydelta.txns`, `daydelta.categories`).
- On first launch, seed built-in categories if `CategoryStore` is empty:
  - Expense: 餐飲, 交通, 購物, 娛樂, 居住, 醫療, 其他
  - Income: 薪資, 獎金, 投資, 其他
- Currency: single currency, formatted via system locale (`Decimal` +
  `.currency` format style). Multi-currency deferred.

## Screens

The app currently uses a single `NavigationStack` in `ContentView`, not a
`TabView`. This change wraps the app in a `TabView`:

- **Tab 1 — 倒數:** existing `ContentView` unchanged.
- **Tab 2 — 記帳:** new, with two sub-pages (segmented/`Picker` or nested tabs).

### 明細 (Ledger)

- Header: current-month summary — income / expense / net balance.
- List: transactions grouped by day, newest first. Each row: category icon,
  name, note, amount (expense red / income green).
- Top-right "+": add transaction (type, amount, category, date, note, optional
  event).
- Swipe to delete; tap to edit (reuses the add sheet).

### 統計 (Stats)

- Period toggle: Week / Month / Year (styled after reference image 1).
- Type toggle: segmented control, expense vs income.
- **Donut:** category share of spending for the period, total amount centered.
- Category breakdown list below the donut: amount + percentage per category
  (like reference image 1).
- **Waffle:** 10×10 grid (100 cells = 100%), cells colored by category share.

## Charts (native Swift Charts)

- **Donut:** `Chart { SectorMark(angle: .value(...), innerRadius: .ratio(0.62)) }`
  with total amount text overlaid in the center.
- **Waffle:** `LazyVGrid` of 100 rounded squares, filled by category proportion.
  No chart library needed.

## Integration points

- **Event detail view:** add a "這趟花費" section summing expenses where
  `txn.eventID == event.id`. This is the realization of the optional
  event-linking decision.
- **Backup (`Backup.swift`):** extend export/import to include `txns` and
  `categories` alongside `events`. The exported JSON becomes a wrapper object
  rather than a bare `[Event]` array — needs a versioned/back-compatible format
  so existing event-only backups still import.

## Testing

- `DayMath`-style pure logic: period bucketing (which txns fall in the selected
  Week/Month/Year), category totals, and percentage computation get a small
  assert-based self-check (follow existing `tests/` convention).
- Decimal money math verified in that check (no float drift).

## Open/deferred

- sunburst — not built
- budget page — not built
- multi-currency — not built
