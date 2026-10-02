# Custom Keypad, Push Pickers & Accounts — Design

**Date:** 2026-10-02
**Status:** Approved, ready for implementation plan

## Goal

Replace the system keyboard for amount entry with a custom in-app numeric keypad,
switch category selection from the dropdown (which the keyboard overlapped) to a
pushed selection page that pops back on tap, and add a full customizable Account
system (Cash / Bank / Credit Card by default) selected the same push way.

## 1. Custom numeric keypad

- New `DayDelta/Keypad.swift` — a fixed bottom grid: `1 2 3 / 4 5 6 / 7 8 9 / . 0 ⌫`.
  Styled dark/monospaced to match the app.
- Amount becomes a large **display** (a `Text`, not a `TextField`) driven by a
  string the keypad edits — no system keyboard for amount.
- Pure edit logic in `Shared/Money.swift`:
  `func applyAmountKey(_ current: String, _ key: AmountKey) -> String`
  with `enum AmountKey { case digit(Int); case dot; case delete }`.
  Rules: at most one ".", at most 2 fractional digits, leading "0" replaced by a
  typed digit, delete removes the last char (empty → ""). Unit-tested.
- Amount for save = `Decimal(string: amountText)`; empty/zero blocks save (as now).
- Note stays a text field (taps bring the system text keyboard); the numeric
  keypad is amount-only.

## 2. Category via pushed page

- Remove `DayDelta/CategoryDropdown.swift` (dropdown overlapped the keyboard).
- New `DayDelta/CategoryPickerView.swift` — a list of the current type's categories
  (color dot + name, current one checked). Tapping one calls an `onSelect(id)` and
  dismisses (pops back) automatically.
- In `TxnEditView` the Category field becomes a row (`NavigationLink`/push) showing
  the selected category; tapping pushes `CategoryPickerView`; selecting returns.

## 3. Account system (full, mirrors Category)

- New model in `Shared/Money.swift`:
  ```swift
  struct Account: Codable, Identifiable, Hashable {
      var id = UUID()
      var name: String
      var colorHex: String
      var builtin: Bool = false
  }
  ```
  `Account.builtins` = Cash, Bank, Credit Card (English, with colors).
  `AccountStore` mirrors `CategoryStore` (JSON in UserDefaults, seeds builtins,
  key `daydelta.accounts`).
- `Txn` gains `accountID: UUID?` — `encodeIfPresent`/`decodeIfPresent` so existing
  transactions decode (nil). New transactions default to the first account.
- New `DayDelta/AccountPickerView.swift` — same push-and-pop selection as category.
- `TxnEditView` adds an Account row (push) next to Category.
- New `DayDelta/AccountManagerView.swift` — add/rename/recolor/delete accounts,
  mirroring `CategoryManagerView` (builtins can't be deleted).

## 4. Combined management screen

- The Money tab's top-right **Edit** opens a management screen with a segmented
  control `Categories | Accounts` that shows `CategoryManagerView` or
  `AccountManagerView`. `LedgerView` owns `accounts` state like `categories`,
  persists both on dismiss.

## 5. Backup

- `BackupData` gains `accounts: [Account]`; export includes them; import merges by
  id (and still falls back to legacy `[Event]` and the events+txns+categories
  shape — missing `accounts` decodes as empty).

## TxnEditView layout (new)

```
  Cancel            New            Save
        ┌───────────────────────┐
        │     $ 1,250           │   ← big amount display
        └───────────────────────┘
   [ Expense | Income ]
   Date      Oct 2, 2026 ›
   Category  ● Food        ›   (push)
   Account   ● Cash        ›   (push)
   Note      ____________
  ┌─────────────────────────────┐
  │  1   2   3                   │
  │  4   5   6                   │   ← custom keypad (amount)
  │  7   8   9                   │
  │  .   0   ⌫                   │
  └─────────────────────────────┘
```

## Files

- Modify `Shared/Money.swift` — `Account`+`AccountStore`+builtins; `Txn.accountID`;
  `AmountKey`+`applyAmountKey`.
- Modify `tests/main.swift` — `applyAmountKey` asserts.
- Create `DayDelta/Keypad.swift`, `DayDelta/CategoryPickerView.swift`,
  `DayDelta/AccountPickerView.swift`, `DayDelta/AccountManagerView.swift`.
- Delete `DayDelta/CategoryDropdown.swift`.
- Modify `DayDelta/TxnEditView.swift` — amount display + keypad + push rows + account.
- Modify `DayDelta/LedgerView.swift` — accounts state; Edit → combined manage screen;
  pass accounts to the editor.
- Modify `DayDelta/CategoryManagerView.swift` — reused inside the combined screen
  (no behavior change; the reset-to-defaults action stays).
- Modify `DayDelta/Backup.swift` + `DayDelta/ContentView.swift` — accounts in backup.

## Testing

- `applyAmountKey` via `swiftc` asserts: digits build up, single dot, max 2
  decimals, delete, delete-to-empty.
- Existing logic tests still pass.
- UI verified by Xcode build + simulator: keypad types the amount (no system
  keyboard); Category/Account push a page and pop on tap; Account defaults on new;
  Edit shows Categories/Accounts; old transactions still load.

## Out of scope

- Account balances / transfers between accounts (just a label per txn).
- Per-account filtering in Stats (could come later).
- Replacing the system keyboard for the Note text field.
