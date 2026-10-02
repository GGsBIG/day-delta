# Add Transaction Page Redesign — Design

**Date:** 2026-10-02
**Status:** Approved, ready for implementation plan

## Goal

Rework the Add/Edit transaction page (`TxnEditView`): make it a single
non-scrolling page, auto-focus the amount with the number keyboard on open,
remove the Event field, and replace the category radio group with a dropdown
that opens a custom staggered-animation popover. Plus a one-time migration that
converts old Chinese built-in category names to English so existing installs
show English without manual reset.

Note: the referenced React `RadialIntro` / shadcn component can't run in this
native SwiftUI app; the "staggered vertical reveal" feel is rebuilt natively.

## 1. Category English migration (pure + tested)

Add to `Shared/Money.swift`:

```swift
/// Renames legacy Chinese built-in category names to their English equivalents.
/// No-op for names already English or unknown. Returns the (possibly) updated list.
func migrateCategoryNames(_ cats: [Category]) -> [Category]
```

- Mapping: 餐飲→Food, 交通→Transport, 購物→Shopping, 娛樂→Entertainment,
  居住→Housing, 醫療→Health, 其他→Other, 薪資→Salary, 獎金→Bonus, 投資→Investment.
- Applies to any category whose `name` is a key in the map (keeps id/type/color).
- `CategoryStore.load()` runs it after decoding; if anything changed, saves back.
- Test in `tests/main.swift`: a list with "餐飲"/"薪資"/"Food" → "Food"/"Salary"/"Food"
  unchanged ids; an all-English list is returned unchanged.

## 2. TxnEditView: single non-scrolling page

- Replace the `Form` with a fixed `VStack` (dark, monospaced, consistent with the
  app). Fields in order: **Type** (Expense/Income segmented), **Amount**,
  **Date**, **Category**, **Note**. No `ScrollView`/`Form` — it does not scroll.
- **Remove the Event section** entirely (the `events`/`eventID` picker). The
  `Txn.eventID` model field stays (used by the event-detail spending total); new
  transactions from this page simply leave it nil.
- **Auto-focus Amount:** `@FocusState private var amountFocused: Bool`; the
  amount `TextField` binds it and `.onAppear`/`.task` sets it true so the
  `.decimalPad` keyboard appears immediately with the cursor in Amount.
- Save/Cancel toolbar unchanged; `defaultDate` behavior unchanged.

## 3. Category dropdown with staggered popover

New file `DayDelta/CategoryDropdown.swift` — `CategoryDropdown`:

- Inputs: `categories: [Category]`, `@Binding selection: UUID?`.
- Closed state: a tappable field showing the selected category's color dot +
  name + a chevron.
- Open state (`@State private var open`): an overlay popover anchored under the
  field listing each category row (color dot + name, current one checked). Rows
  animate in top-to-bottom — each row offset/opacity driven by an `appeared`
  flag with a per-index delay (~0.04s × index) using `.spring`/`.bouncy`.
  A full-screen transparent tap-catcher behind the popover dismisses it.
  Selecting a row sets `selection` and closes with animation.
- Used in `TxnEditView`'s Category field, replacing `CategoryRadioGroup`.
- **Delete `DayDelta/RadioGroup.swift`** (radio group no longer used; xcodegen
  globs the folder so removing the file drops it from the build).

## Files

- Modify `Shared/Money.swift` — `migrateCategoryNames`, call in `CategoryStore.load()`.
- Modify `tests/main.swift` — migration test.
- Create `DayDelta/CategoryDropdown.swift` — `CategoryDropdown`.
- Delete `DayDelta/RadioGroup.swift`.
- Modify `DayDelta/TxnEditView.swift` — single page, remove Event, autofocus, dropdown.

## Testing

- `migrateCategoryNames` via `swiftc` asserts (logic).
- UI verified by Xcode build + simulator: opening Add shows the keyboard focused
  on Amount; no Event field; page does not scroll; Category opens a staggered
  popover and selecting updates the field; old Chinese categories now read English.

## Out of scope

- Changing the edit-existing-transaction entry (same view; it still works, just
  without Event and with the new dropdown).
- Keyboard "Done"/toolbar accessory (decimal pad dismiss by tapping elsewhere is
  acceptable; add later if wanted).
