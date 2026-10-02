# Bottom Tabs Restructure & Accounts Overview — Design

**Date:** 2026-10-02
**Status:** Approved

## Goal

Split the Money tab's internal Ledger/Stats segmented control into separate
bottom tabs, add an Accounts overview tab showing each account's balance, and
remove the top segmented row.

## Bottom bar

```
Days   Ledger  ( + )  Stats   Accounts
```

- Four tabs: **Days** (countdown), **Ledger** (month calendar), **Stats**
  (charts), **Accounts** (balances).
- The center circular **Add** appears only on the **Ledger** tab (adding a
  transaction belongs to the ledger); it collapses with the existing `.bouncy`
  animation when another tab is selected. Days has no Add.
- Tab index mapping: 0 Days, 1 Ledger, 2 Stats, 3 Accounts.

## View changes

### LedgerView (calendar only)
- Remove the `page` state, the principal `Ledger/Stats` segmented `Picker`, and
  the Stats branch. The body is the calendar + selected-day list directly.
- Navigation title → "Ledger". Keep the top-right **Edit** (opens `ManageView`
  for Categories/Accounts) and the `requestAddTxn`-driven add sheet and the
  tap-to-edit sheet. Keeps owning txns/categories/accounts state.

### StatsView (self-loading tab)
- Change from taking `txns`/`categories` parameters to loading them itself:
  `@State private var txns = TxnStore.load()`, `@State private var categories =
  CategoryStore.load()`, reloaded in `.onAppear`. Wrap its body in a
  `NavigationStack` with title "Stats" (it was previously inside LedgerView's).

### AccountsView (new)
- Loads `txns` and `accounts` from stores (`@State` + `.onAppear`).
- Top: **total balance** = all income − all expense (big monospaced number).
- A list, one row per account: color dot + name + that account's balance
  (`accountBalance`), green if ≥ 0 else red.
- If any transactions have `accountID == nil`, append an **Unassigned** row with
  their net so the rows reconcile to the total.
- `NavigationStack`, title "Accounts".

### RootView (DayDeltaApp)
- Four tabs via the existing custom container; the Days↔others transition keeps
  the directional slide (Days slides from leading; the rest from trailing).
- Bottom bar has four `tabButton`s; the center `addButton` is inserted only when
  `tab == 1` (Ledger), transitioning with scale+opacity under the tab animation.
- `LedgerView(requestAddTxn:)` still receives the binding set by the center Add.

## Pure logic (Shared/Money.swift, tested)

```swift
/// Net balance for one account: its income minus its expense.
func accountBalance(_ txns: [Txn], accountID: UUID?) -> Decimal
```
- Sums `amount` of matching-account income minus matching-account expense.
- `accountID == nil` computes the Unassigned bucket (txns with no account).
- Test: a mix of income/expense across two accounts + one unassigned returns the
  right per-account and unassigned values.

## Files

- Modify `Shared/Money.swift` — `accountBalance`.
- Modify `tests/main.swift` — `accountBalance` asserts.
- Create `DayDelta/AccountsView.swift`.
- Modify `DayDelta/StatsView.swift` — self-load + own NavigationStack/title.
- Modify `DayDelta/LedgerView.swift` — remove segmented/Stats; title "Ledger".
- Modify `DayDelta/DayDeltaApp.swift` — four tabs; Add only on Ledger.

## Testing

- `accountBalance` via `swiftc` asserts.
- Build + simulator: four bottom tabs; no top segmented; Add only on Ledger and
  collapses elsewhere; Stats and Accounts load data; Accounts shows per-account
  balances + total.

## Out of scope

- Account transfers, per-account transaction filtering/drill-down, editing a
  transaction's account from the Accounts page (use the editor).
