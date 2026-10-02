# Money Controls Redesign — Design

**Date:** 2026-10-02
**Status:** Approved, ready for implementation plan

## Goal

Refresh the Money tab's controls: an animated radio-group category picker in the
transaction editor, a top-right **Edit** button for category management, and a
bottom **Add** button (center circle in the tab bar) that appears only on the
Money tab and collapses smoothly when switching to Days. Plus a "Reset to default
categories" action to clear old (Chinese) saved data on existing installs.

Note: the referenced React `@animate-ui` RadioGroup / shadcn code cannot run in
this native SwiftUI app — it's rebuilt as a SwiftUI equivalent.

## A. Animated radio-group category picker

New file `DayDelta/RadioGroup.swift`:

- `RadioRow` — one selectable row: a radio indicator (outer ring; inner filled
  dot that scales/fades in with `.bouncy` when selected) + a trailing label
  content. Tapping selects.
- `CategoryRadioGroup` — given `categories: [Category]` and
  `@Binding selection: UUID?`, renders a vertical list of `RadioRow`s, each
  showing the category's color dot + name. Selecting animates the indicator.

Used in `TxnEditView`: the current `Picker("Category", selection:)` dropdown in
the "Category" section is replaced by `CategoryRadioGroup(categories:
typeCategories, selection: $categoryID)`. The existing type-switch reset of
`categoryID` and the `defaultDate` behavior are unchanged.

## B. Top-right Edit (category management)

In `LedgerView` the trailing toolbar item changes from the `Menu` ("Add" /
"Categories") to a single **Edit** button that sets `managingCategories = true`
(opens `CategoryManagerView`). The principal Ledger/Stats `Picker` stays.
The Add action is removed here (it moves to the bottom bar, section C).

## C. Bottom Add button (center circle, Money-only, collapses to Days)

In `RootView` (`DayDeltaApp.swift`) the bottom bar becomes:

```
[ Days ]        ( + )        [ Money ]
```

- `Days` and `Money` are the existing equal-width tab buttons (left / right).
- A center circular `+` button (≈56pt, accent fill, raised slightly above the
  bar) sits between them, shown only when `tab == 1` (Money).
- When `tab == 0` (Days) the center button is absent; its insertion/removal uses
  a scale + opacity transition under the existing `withAnimation(.bouncy(...))`
  used for tab switches, so it collapses/expands silkily and Days/Money recenter.
- Tapping the center button requests the add sheet.

Cross-view wiring: `RootView` owns `@State private var requestAddTxn = false` and
passes `LedgerView(requestAddTxn: $requestAddTxn)`. `LedgerView` gains
`@Binding var requestAddTxn: Bool` and presents its add `TxnEditView` sheet on
that binding (replacing the internal `addingTxn` state), using its own
`selectedDay` as `defaultDate`. This is safe because `LedgerView` only exists
while `tab == 1`, which is exactly when the center button is tappable.

## D. Reset to default categories

In `CategoryManagerView`, add a destructive **"Reset to default categories"**
button (its own section at the bottom) that replaces `categories` with
`Category.builtins` (the English seed) and saves. This lets existing installs
clear leftover Chinese category data. Confirmation via a simple
`confirmationDialog` before resetting.

## Files

- Create `DayDelta/RadioGroup.swift` — `RadioRow`, `CategoryRadioGroup`.
- Modify `DayDelta/TxnEditView.swift` — category section uses `CategoryRadioGroup`.
- Modify `DayDelta/LedgerView.swift` — trailing Edit button; add sheet driven by
  `@Binding requestAddTxn`.
- Modify `DayDelta/DayDeltaApp.swift` — bottom bar center Add button + wiring.
- Modify `DayDelta/CategoryManagerView.swift` — reset-to-defaults action.

## Testing

This change is UI-only; no new pure logic. Verification is the Xcode build
(`BUILD SUCCEEDED`) plus a simulator run confirming: radio group selects with
animation; top-right Edit opens the category manager; the center Add appears on
Money and collapses when switching to Days; Add opens the editor on the selected
day; Reset restores English categories. Existing `swiftc` logic tests must still
pass (unchanged).

## Out of scope

- Generic reusable radio group beyond category use (YAGNI).
- Reordering categories; icon in the radio row (color dot + name only).
- Per-tab Add on the Days tab (events keep their own toolbar +).
