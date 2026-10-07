---
description: Audit the architecture, delete all dead/unnecessary code, keep it clean, then build/test/commit/push.
---

Audit the whole DayDelta codebase and leave the leanest clean-code structure. Be
honest — if nothing is dead, say so plainly; never invent deletions.

## 1. Find dead / unnecessary code
- Build and read compiler warnings:
  `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -scheme DayDelta -destination 'generic/platform=iOS Simulator' build CODE_SIGNING_ALLOWED=NO`
  — flag anything "never used / never read / unused / redundant".
- Catch what the compiler won't: for every top-level `func`/`let` in `Shared/`
  and every `private` member in `DayDelta/*.swift`, grep its usages across
  `DayDelta/` + `Shared/`. Anything referenced **only at its definition** is dead.
- Also hunt: orphaned helpers left by reverts, stale doc comments, duplicated
  logic, glass-on-glass/duplicate layers, reinvented stdlib, unused `@State`.

## 2. Remove & simplify (ponytail)
- Delete the dead code. Keep anything still used — even if used only once.
- Prefer the laziest fix: stdlib/native before custom, ONE shared helper over
  duplication, shortest working diff. No speculative abstractions.
- Keep the architecture as **lightweight MVVM** (`@Observable AppData` + pure
  logic in `Shared/`). Do NOT restructure into VIPER/Clean — that's over-engineering
  for this app.

## 3. Verify (never claim done without this)
- `swiftc Shared/DayMath.swift Shared/Money.swift tests/main.swift -o /tmp/t && /tmp/t`
- the xcodebuild above — must succeed with no new warnings.

## 4. Report & ship
- One line per removal: what was cut and why.
- Commit **and** push with a descriptive message + the repo's co-author trailer.

$ARGUMENTS
