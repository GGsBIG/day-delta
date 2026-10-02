# Add Transaction Page Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the Add/Edit transaction page a single non-scrolling screen that auto-focuses Amount with the number keyboard, drops the Event field, and uses a staggered-animation category dropdown; plus auto-migrate old Chinese category names to English.

**Architecture:** A tested pure `migrateCategoryNames` runs inside `CategoryStore.load()`. A new `CategoryDropdown` SwiftUI component replaces the radio group (which is deleted). `TxnEditView` moves from `Form` to a fixed `VStack` with `@FocusState` auto-focus.

**Tech Stack:** Swift 5, SwiftUI, iOS 17+. No new dependencies (the referenced React/shadcn `RadialIntro` cannot run here).

**Spec:** `docs/superpowers/specs/2026-10-02-add-page-redesign-design.md`

**Commands:**
- Logic tests: `swiftc Shared/DayMath.swift Shared/Money.swift tests/main.swift -o /tmp/t && /tmp/t`
- Build: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -scheme DayDelta -destination 'generic/platform=iOS Simulator' build CODE_SIGNING_ALLOWED=NO 2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED"` (run `DEVELOPER_DIR=... xcodegen generate` first if `.xcodeproj` is missing, and after deleting a source file)

---

## File Structure

- Modify `Shared/Money.swift` — add `migrateCategoryNames`, call it in `CategoryStore.load()`.
- Modify `tests/main.swift` — migration asserts.
- Create `DayDelta/CategoryDropdown.swift` — `CategoryDropdown` (staggered popover).
- Delete `DayDelta/RadioGroup.swift` — radio group no longer used.
- Modify `DayDelta/TxnEditView.swift` — single page, remove Event, autofocus Amount, use `CategoryDropdown`.

---

## Task 1: Category name migration (TDD)

**Files:**
- Modify: `Shared/Money.swift`
- Test: `tests/main.swift`

- [ ] **Step 1: Write the failing test**

In `tests/main.swift`, find the line `print("all money tests passed")` and insert this block immediately BEFORE it:

```swift
// migrateCategoryNames: legacy Chinese builtin names -> English; ids kept; English untouched
let legacyFoodID = UUID()
let legacyCats = [
    Category(id: legacyFoodID, name: "餐飲", type: .expense, icon: nil, colorHex: "#4F9DFF", builtin: true),
    Category(name: "薪資", type: .income, icon: nil, colorHex: "#22C55E", builtin: true),
    Category(name: "Food", type: .expense, icon: nil, colorHex: "#4F9DFF", builtin: true),
]
let migratedCats = migrateCategoryNames(legacyCats)
assert(migratedCats[0].name == "Food" && migratedCats[0].id == legacyFoodID)
assert(migratedCats[1].name == "Salary")
assert(migratedCats[2].name == "Food")   // already English -> unchanged
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swiftc Shared/DayMath.swift Shared/Money.swift tests/main.swift -o /tmp/t && /tmp/t`
Expected: FAIL — `cannot find 'migrateCategoryNames' in scope`.

- [ ] **Step 3: Add the function**

In `Shared/Money.swift`, find:
```swift
enum CategoryStore {
    private static let key = "daydelta.categories"
```
Insert ABOVE that `enum CategoryStore {` line:
```swift
/// Renames legacy Chinese built-in category names to English. Names that aren't
/// in the map (already English, or custom) are left untouched; id/type/color kept.
func migrateCategoryNames(_ cats: [Category]) -> [Category] {
    let map = ["餐飲": "Food", "交通": "Transport", "購物": "Shopping",
               "娛樂": "Entertainment", "居住": "Housing", "醫療": "Health",
               "其他": "Other", "薪資": "Salary", "獎金": "Bonus", "投資": "Investment"]
    return cats.map { c in
        guard let english = map[c.name] else { return c }
        var m = c
        m.name = english
        return m
    }
}

```

- [ ] **Step 4: Wire it into `CategoryStore.load()`**

In `Shared/Money.swift`, find:
```swift
    static func load() -> [Category] {
        if let data = UserDefaults.standard.data(forKey: key),
           let cats = try? JSONDecoder().decode([Category].self, from: data),
           !cats.isEmpty {
            return cats
        }
        save(Category.builtins)
        return Category.builtins
    }
```
Replace with:
```swift
    static func load() -> [Category] {
        if let data = UserDefaults.standard.data(forKey: key),
           let cats = try? JSONDecoder().decode([Category].self, from: data),
           !cats.isEmpty {
            let migrated = migrateCategoryNames(cats)
            if migrated != cats { save(migrated) }   // one-time: persist English names
            return migrated
        }
        save(Category.builtins)
        return Category.builtins
    }
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `swiftc Shared/DayMath.swift Shared/Money.swift tests/main.swift -o /tmp/t && /tmp/t`
Expected: PASS — prints `all DayMath tests passed` and `all money tests passed`.

- [ ] **Step 6: Commit**

```bash
git add Shared/Money.swift tests/main.swift
git commit -m "feat: migrate legacy Chinese category names to English on load"
```

---

## Task 2: CategoryDropdown component

**Files:**
- Create: `DayDelta/CategoryDropdown.swift`

This is additive — `RadioGroup.swift` still exists, so the build stays green.

- [ ] **Step 1: Create the file**

Create `DayDelta/CategoryDropdown.swift` with EXACTLY this content:

```swift
import SwiftUI

/// A category picker: a tappable field that opens a popover whose rows reveal
/// top-to-bottom with a staggered spring. ponytail: dismisses on select or by
/// tapping the field again; no outside-tap scrim (add if it feels needed).
struct CategoryDropdown: View {
    let categories: [Category]
    @Binding var selection: UUID?

    @State private var open = false
    @State private var appeared = false

    private var selected: Category? { categories.first { $0.id == selection } }

    var body: some View {
        Button {
            withAnimation(.bouncy(duration: 0.3)) { open.toggle() }
        } label: {
            HStack(spacing: 8) {
                if let s = selected {
                    Circle().fill(Color(hex: s.colorHex)).frame(width: 12, height: 12)
                    Text(s.name)
                } else {
                    Text("Select category").foregroundStyle(.gray)
                }
                Spacer()
                Image(systemName: "chevron.down")
                    .rotationEffect(.degrees(open ? 180 : 0))
                    .foregroundStyle(.gray)
            }
            .font(.system(.body, design: .monospaced))
            .foregroundStyle(.white)
            .padding(.vertical, 10).padding(.horizontal, 12)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color(white: 0.1)))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .overlay(alignment: .topLeading) {
            if open { popover.offset(y: 48) }
        }
        .zIndex(open ? 1 : 0)
    }

    private var popover: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(categories.enumerated()), id: \.element.id) { i, c in
                row(c, index: i)
            }
        }
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(white: 0.14)))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.white.opacity(0.1)))
        .shadow(color: .black.opacity(0.5), radius: 12, y: 6)
        .transition(.opacity)
        .onAppear { appeared = true }
        .onDisappear { appeared = false }
    }

    private func row(_ c: Category, index: Int) -> some View {
        Button {
            selection = c.id
            withAnimation(.bouncy(duration: 0.3)) { open = false }
        } label: {
            HStack(spacing: 8) {
                Circle().fill(Color(hex: c.colorHex)).frame(width: 12, height: 12)
                Text(c.name).font(.system(.body, design: .monospaced))
                Spacer()
                if c.id == selection {
                    Image(systemName: "checkmark").font(.caption.bold())
                }
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 14).padding(.vertical, 9)
            .frame(width: 240, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : -8)
        .animation(.spring(response: 0.3, dampingFraction: 0.7)
                    .delay(Double(index) * 0.04), value: appeared)
    }
}
```

- [ ] **Step 2: Verify the build**

Run the build command. Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add DayDelta/CategoryDropdown.swift
git commit -m "feat: staggered category dropdown component"
```

---

## Task 3: Rewrite TxnEditView; delete RadioGroup

**Files:**
- Modify: `DayDelta/TxnEditView.swift`
- Delete: `DayDelta/RadioGroup.swift`

- [ ] **Step 1: Replace the whole TxnEditView body/state**

Replace the ENTIRE contents of `DayDelta/TxnEditView.swift` with:

```swift
import SwiftUI

/// Add/edit one transaction. Single non-scrolling page; Amount is focused on open
/// so the number keyboard appears immediately.
struct TxnEditView: View {
    let txn: Txn?
    let categories: [Category]
    var defaultDate: Date? = nil
    let onSave: (Txn) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var type: TxnType
    @State private var amount: Decimal?
    @State private var categoryID: UUID?
    @State private var date: Date
    @State private var note: String
    @State private var eventID: UUID?          // preserved on edit; nil for new
    @FocusState private var amountFocused: Bool

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
        _note = State(initialValue: txn?.note ?? "")
        _eventID = State(initialValue: txn?.eventID)
    }

    private var typeCategories: [Category] { categories.filter { $0.type == type } }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                Picker("Type", selection: $type) {
                    Text("Expense").tag(TxnType.expense)
                    Text("Income").tag(TxnType.income)
                }
                .pickerStyle(.segmented)

                field("Amount") {
                    TextField("0", value: $amount, format: .number)
                        .keyboardType(.decimalPad)
                        .focused($amountFocused)
                        .font(.system(.title2, design: .monospaced))
                }
                field("Date") {
                    DatePicker("", selection: $date, displayedComponents: .date)
                        .labelsHidden()
                }
                field("Category") {
                    CategoryDropdown(categories: typeCategories, selection: $categoryID)
                }
                field("Note") {
                    TextField("Note", text: $note)
                        .font(.system(.body, design: .monospaced))
                }
                Spacer()
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
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
            // Keep the chosen category valid for the current type.
            .onChange(of: type) { _, _ in
                if let cid = categoryID, !typeCategories.contains(where: { $0.id == cid }) {
                    categoryID = typeCategories.first?.id
                }
            }
            .onAppear { if categoryID == nil { categoryID = typeCategories.first?.id } }
            .task { amountFocused = true }   // auto-open keyboard on Amount
        }
        .preferredColorScheme(.dark)
        .tint(.white)
    }

    @ViewBuilder
    private func field<Content: View>(_ label: String,
                                      @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.gray)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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

- [ ] **Step 2: Delete the unused radio group**

Run:
```bash
git rm DayDelta/RadioGroup.swift
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodegen generate
```

- [ ] **Step 3: Verify the build**

Run the build command. Expected: `** BUILD SUCCEEDED **` (nothing references `CategoryRadioGroup`/`RadioRow` anymore).

- [ ] **Step 4: Commit**

```bash
git add DayDelta/TxnEditView.swift DayDelta/RadioGroup.swift
git commit -m "feat: single-page transaction editor with autofocus and category dropdown"
```

---

## Task 4: Run it on the simulator

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

- [ ] **Step 2: Confirm behavior**

Open Money → tap the center Add. Expected: the page does not scroll; the number
keyboard is already up with the cursor in Amount; there is no Event field; Category
is a dropdown that opens a staggered popover of English categories; selecting one
updates the field. If old data existed, categories read English (migration).
Screenshot the editor (with the dropdown open) and inspect.

> To capture without the first-run notification alert dimming it, reuse the prior
> approach: temporarily stub `Notifications.requestAuthIfNeeded`, default the tab
> to Money and `requestAddTxn` to true, build, capture, then revert.

No commit — verification only.

---

## Self-review notes

- **Spec coverage:** migration (Task 1); single non-scrolling page + remove Event +
  autofocus Amount (Task 3 Step 1); category dropdown with staggered popover (Task 2 +
  used in Task 3); delete RadioGroup (Task 3 Step 2); simulator verify (Task 4).
- **Type consistency:** `migrateCategoryNames([Category]) -> [Category]`,
  `CategoryDropdown(categories:selection:)`, `Color(hex:)`, `Category` (Equatable via
  Hashable for `migrated != cats`) used consistently. `eventID` state kept so editing
  preserves an existing link while new transactions stay nil.
- **Build-order safety:** Task 2 is additive (RadioGroup still present); RadioGroup is
  only deleted in Task 3 after TxnEditView stops referencing it.
- **Deferred:** outside-tap-to-dismiss scrim on the dropdown; keyboard Done accessory.
