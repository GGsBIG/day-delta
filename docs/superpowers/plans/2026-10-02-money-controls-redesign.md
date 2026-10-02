# Money Controls Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Animated radio-group category picker, a top-right Edit button for category management, a bottom center Add button (Money-only, collapses to Days), and a reset-to-default-categories action.

**Architecture:** New SwiftUI `RadioGroup.swift` rebuilds the referenced React animate-ui radio group natively. `TxnEditView` swaps its category dropdown for it. `LedgerView` moves Add out to the bottom bar via a `@Binding`, keeping Edit top-right. `RootView` hosts the center Add button with a collapse transition. `CategoryManagerView` gains a reset action.

**Tech Stack:** Swift 5, SwiftUI, iOS 17+. No new dependencies (the React/shadcn code cannot run here).

**Spec:** `docs/superpowers/specs/2026-10-02-money-controls-redesign-design.md`

**Build command:** `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -scheme DayDelta -destination 'generic/platform=iOS Simulator' build CODE_SIGNING_ALLOWED=NO 2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED"` (run `DEVELOPER_DIR=... xcodegen generate` first if `.xcodeproj` is missing)

---

## File Structure

- Create `DayDelta/RadioGroup.swift` — `RadioRow`, `CategoryRadioGroup`.
- Modify `DayDelta/TxnEditView.swift` — category section uses `CategoryRadioGroup`.
- Modify `DayDelta/LedgerView.swift` — `@Binding requestAddTxn`, Edit toolbar button, add-sheet on the binding.
- Modify `DayDelta/DayDeltaApp.swift` — pass the binding + center Add button.
- Modify `DayDelta/CategoryManagerView.swift` — reset-to-defaults action.

These are SwiftUI views; there is no standalone compile check — each task verifies with the full Xcode build. Ignore per-file SourceKit "cannot find type" warnings. The existing `swiftc` logic tests are unaffected but should still pass:
`swiftc Shared/DayMath.swift Shared/Money.swift tests/main.swift -o /tmp/t && /tmp/t`

---

## Task 1: Animated radio group

**Files:**
- Create: `DayDelta/RadioGroup.swift`

- [ ] **Step 1: Create the file**

Create `DayDelta/RadioGroup.swift` with EXACTLY this content:

```swift
import SwiftUI

/// One radio row: an animated indicator (ring + inner dot that springs in when
/// selected) plus trailing label content. Tapping selects.
struct RadioRow<Label: View>: View {
    let isSelected: Bool
    let action: () -> Void
    @ViewBuilder var label: () -> Label

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .strokeBorder(isSelected ? Color.white : Color.white.opacity(0.35),
                                      lineWidth: 2)
                        .frame(width: 20, height: 20)
                    Circle()
                        .fill(Color.white)
                        .frame(width: 10, height: 10)
                        .scaleEffect(isSelected ? 1 : 0.01)
                        .opacity(isSelected ? 1 : 0)
                }
                label()
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(.bouncy(duration: 0.35), value: isSelected)
    }
}

/// Category chooser as a vertical animated radio group.
struct CategoryRadioGroup: View {
    let categories: [Category]
    @Binding var selection: UUID?

    var body: some View {
        VStack(spacing: 4) {
            ForEach(categories) { c in
                RadioRow(isSelected: selection == c.id) {
                    selection = c.id
                } label: {
                    HStack(spacing: 8) {
                        Circle().fill(Color(hex: c.colorHex)).frame(width: 12, height: 12)
                        Text(c.name).font(.system(.body, design: .monospaced))
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }
}
```

- [ ] **Step 2: Verify the build**

Run the build command. Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add DayDelta/RadioGroup.swift
git commit -m "feat: animated radio group (category picker)"
```

---

## Task 2: Use the radio group in TxnEditView

**Files:**
- Modify: `DayDelta/TxnEditView.swift`

- [ ] **Step 1: Replace the Category section**

In `DayDelta/TxnEditView.swift`, find:
```swift
                Section("Category") {
                    Picker("Category", selection: $categoryID) {
                        ForEach(typeCategories) { c in
                            Text(c.name).tag(Optional(c.id))
                        }
                    }
                }
```
Replace with:
```swift
                Section("Category") {
                    CategoryRadioGroup(categories: typeCategories, selection: $categoryID)
                }
```

- [ ] **Step 2: Verify the build**

Run the build command. Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add DayDelta/TxnEditView.swift
git commit -m "feat: radio-group category picker in transaction editor"
```

---

## Task 3: Move Add out of LedgerView; Edit stays top-right

**Files:**
- Modify: `DayDelta/LedgerView.swift`

- [ ] **Step 1: Add an init with a bound add-request flag, drop `addingTxn`**

In `DayDelta/LedgerView.swift`, find:
```swift
    @State private var editingTxn: Txn?
    @State private var addingTxn = false
    @State private var managingCategories = false
    @State private var monthAnchor = Date()
    @State private var selectedDay = Calendar.current.startOfDay(for: Date())
```
Replace with:
```swift
    @State private var editingTxn: Txn?
    @State private var managingCategories = false
    @State private var monthAnchor = Date()
    @State private var selectedDay = Calendar.current.startOfDay(for: Date())

    /// Driven by the bottom-bar Add button in RootView. Defaults to a constant so
    /// LedgerView still compiles/previews standalone.
    @Binding var requestAddTxn: Bool

    init(requestAddTxn: Binding<Bool> = .constant(false)) {
        _requestAddTxn = requestAddTxn
    }
```

- [ ] **Step 2: Replace the trailing toolbar Menu with an Edit button**

Find:
```swift
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button { addingTxn = true } label: { Label("Add", systemImage: "plus") }
                        Button { managingCategories = true } label: {
                            Label("Categories", systemImage: "tag")
                        }
                    } label: { Image(systemName: "plus") }
                }
```
Replace with:
```swift
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Edit") { managingCategories = true }
                }
```

- [ ] **Step 3: Drive the add sheet from the binding**

Find:
```swift
            .sheet(isPresented: $addingTxn) {
                TxnEditView(txn: nil, categories: categories, defaultDate: selectedDay) { saved in
                    txns.append(saved); persist()
                }
            }
```
Replace with:
```swift
            .sheet(isPresented: $requestAddTxn) {
                TxnEditView(txn: nil, categories: categories, defaultDate: selectedDay) { saved in
                    txns.append(saved); persist()
                }
            }
```

- [ ] **Step 4: Verify the build**

Run the build command. Expected: `** BUILD SUCCEEDED **`. (`LedgerView()` elsewhere still compiles because `requestAddTxn` defaults to `.constant(false)`.)

- [ ] **Step 5: Commit**

```bash
git add DayDelta/LedgerView.swift
git commit -m "feat: ledger Edit button, Add driven by bound flag"
```

---

## Task 4: Bottom center Add button in RootView

**Files:**
- Modify: `DayDelta/DayDeltaApp.swift`

- [ ] **Step 1: Add the add-request state and pass it to LedgerView**

In `DayDelta/DayDeltaApp.swift`, find:
```swift
private struct RootView: View {
    @State private var tab = 0

    var body: some View {
```
Replace with:
```swift
private struct RootView: View {
    @State private var tab = 0
    @State private var requestAddTxn = false

    var body: some View {
```

Find:
```swift
                } else {
                    LedgerView()
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                }
```
Replace with:
```swift
                } else {
                    LedgerView(requestAddTxn: $requestAddTxn)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                }
```

- [ ] **Step 2: Add the center Add button to the tab bar**

Find:
```swift
    private var tabBar: some View {
        HStack(spacing: 0) {
            tabButton(0, "Days", "calendar")
            tabButton(1, "Money", "dollarsign.circle")
        }
        .padding(.top, 8)
        .background(.black)
        .overlay(alignment: .top) {
            Rectangle().fill(.white.opacity(0.1)).frame(height: 0.5)
        }
    }
```
Replace with:
```swift
    private var tabBar: some View {
        HStack(spacing: 0) {
            tabButton(0, "Days", "calendar")
            if tab == 1 {
                addButton
                    .transition(.scale.combined(with: .opacity))
            }
            tabButton(1, "Money", "dollarsign.circle")
        }
        .padding(.top, 8)
        .background(.black)
        .overlay(alignment: .top) {
            Rectangle().fill(.white.opacity(0.1)).frame(height: 0.5)
        }
    }

    /// Center Add — only present on the Money tab. Its insertion/removal rides the
    /// tab-switch `.bouncy` animation, so it springs in / collapses out silkily.
    private var addButton: some View {
        Button {
            requestAddTxn = true
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(.black)
                .frame(width: 56, height: 56)
                .background(Circle().fill(.white))
                .offset(y: -12)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.impact, trigger: requestAddTxn)
    }
```

- [ ] **Step 3: Verify the build**

Run the build command. Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Commit**

```bash
git add DayDelta/DayDeltaApp.swift
git commit -m "feat: bottom center Add button, Money-only with collapse"
```

---

## Task 5: Reset to default categories

**Files:**
- Modify: `DayDelta/CategoryManagerView.swift`

- [ ] **Step 1: Add the reset state**

In `DayDelta/CategoryManagerView.swift`, find:
```swift
    @State private var editing: Category?
    @State private var adding = false
```
Replace with:
```swift
    @State private var editing: Category?
    @State private var adding = false
    @State private var confirmingReset = false
```

- [ ] **Step 2: Add the reset section and confirmation dialog**

Find:
```swift
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
```
Replace with:
```swift
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
            Section {
                Button(role: .destructive) { confirmingReset = true } label: {
                    Label("Reset to default categories", systemImage: "arrow.counterclockwise")
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
        .confirmationDialog("Reset categories?", isPresented: $confirmingReset,
                            titleVisibility: .visible) {
            Button("Reset to defaults", role: .destructive) {
                categories = Category.builtins
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Replaces all categories with the English defaults. Custom categories are removed.")
        }
    }
```

- [ ] **Step 3: Verify the build**

Run the build command. Expected: `** BUILD SUCCEEDED **`. The `categories` binding is persisted by `LedgerView`'s existing `.onDisappear { CategoryStore.save(categories) }`, so the reset survives.

- [ ] **Step 4: Commit**

```bash
git add DayDelta/CategoryManagerView.swift
git commit -m "feat: reset to default categories"
```

---

## Task 6: Run it on the simulator

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

On the Money tab verify: the center Add button is present; switching to Days
collapses it smoothly and it is gone; switching back springs it in. Tapping Add
opens the editor with the category list as an animated radio group (dot springs
in on selection) defaulting the date to the selected day. Top-right "Edit" opens
the category manager; its "Reset to default categories" restores the English
set. Screenshot the Money tab and the editor and inspect.

> To exercise the radio group without the first-run notification alert dimming the
> capture, reuse the prior-run approach if needed: temporarily stub
> `Notifications.requestAuthIfNeeded` and default the tab, then revert.

No commit — verification only.

---

## Self-review notes

- **Spec coverage:** radio group (Task 1) + used in editor (Task 2); top-right Edit
  (Task 3 Step 2); Add removed from LedgerView and driven by binding (Task 3 Steps 1,3);
  bottom center Add, Money-only + collapse (Task 4); reset categories (Task 5);
  simulator verification (Task 6). Categories-in-English is already in the codebase
  (prior `i18n` commit); Task 5 is the migration path for old installs.
- **Type consistency:** `CategoryRadioGroup(categories:selection:)`, `RadioRow(isSelected:action:label:)`,
  `LedgerView(requestAddTxn:)`, `Category.builtins`, `Color(hex:)` used consistently.
  `requestAddTxn` is a `Bool` binding in both `RootView` and `LedgerView`.
- **Build-order safety:** `LedgerView.init` defaults `requestAddTxn` to `.constant(false)`,
  so Task 3 builds before Task 4 wires the real binding.
- **Deferred:** generic radio group, category reordering, radio-row icons.
