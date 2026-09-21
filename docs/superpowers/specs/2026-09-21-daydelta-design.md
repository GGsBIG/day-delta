# DayDelta — Design

**Date:** 2026-09-21

A minimal iOS app that shows the number of days until / since a set of dates,
in an all-black, monospaced "code" aesthetic, with a configurable Home Screen
widget.

## Goals

- Track multiple dated events in a list.
- For each event, show the day delta: countdown if the date is in the future,
  count-up if it is in the past. Direction is automatic, not a stored setting.
- A configurable Home Screen widget: each widget instance is set up by the
  user directly (enter a title + pick a date in the widget's long-press
  configuration). The widget is self-contained and does not read the app's
  event list — this avoids needing an App Group (which requires a paid Apple
  Developer account). App list and widget are configured independently.
- Pure black background, large monospaced numbers, title + number only (no
  color coding, no emoji).
- Run on the user's own iPhone via free Apple ID signing.

## Non-Goals (YAGNI)

- No categories, tags, colors, emoji, or icons per event.
- No reminders/notifications.
- No iCloud sync, no CoreData/SwiftData, no backend.
- No recurring events.
- No Lock Screen / StandBy widgets in v1 (Home Screen small + medium only).

## Architecture

One Xcode project, two independent targets (no App Group):

1. **DayDelta** (iOS app, SwiftUI) — event list, add / edit / delete. Stores
   its list in its own standard `UserDefaults`.
2. **DayDeltaWidget** (Widget Extension, WidgetKit + SwiftUI + AppIntents) —
   Home Screen widget, small + medium. Self-configured: the user enters a
   title + date in the widget's configuration; those values are stored by the
   system per widget instance. The widget does not read app data.

> ponytail: dropping the App Group removes the shared container, the
> `EntityQuery`, and the paid-account requirement. Cost: a widget event is
> entered separately from the app list (no sync). Accepted tradeoff for a free
> personal-team build.

### Shared code

A small shared Swift file compiled into **both** targets (via target
membership) — pure functions only, no storage:

- `dayDelta(...)` computation
- `deltaText(...)` / subtitle formatting helper

`Event` model and `EventStore` live in the **app target only**.

## Data Model

```swift
struct Event: Codable, Identifiable, Hashable {
    var id: UUID
    var title: String
    var targetDate: Date
}
```

Direction is **computed**, never stored:

- `targetDate` today or later → countdown ("N days" / "TODAY" when 0)
- `targetDate` before today → count-up ("N days ago")

## Storage

- App target only: JSON-encoded `[Event]` stored in `UserDefaults.standard`
  under one key.
- `EventStore` provides `load() -> [Event]` and `save([Event])`.
- The widget stores nothing here; its configuration lives in the AppIntent
  values the system persists per widget instance.

> ponytail: JSON in standard UserDefaults, not CoreData/SwiftData. A flat list
> of {title, date} needs nothing more. Revisit if the list grows to hundreds of
> entries or needs queries.

## Day Computation (the logic that gets a test)

```swift
func dayDelta(to target: Date, from now: Date = Date(),
              calendar: Calendar = .current) -> Int {
    let a = calendar.startOfDay(for: now)
    let b = calendar.startOfDay(for: target)
    return calendar.dateComponents([.day], from: a, to: b).day ?? 0
}
```

Both operands are normalized to `startOfDay` first — this avoids the
off-by-one where a 23-hour gap rounds to 0 days. Positive = future (countdown),
negative = past (count-up), 0 = today.

**Test (assert-based, no framework needed):** future date → positive; past
date → negative; same day different hours → 0; across DST boundary → correct
count.

## Display Formatting

`func deltaText(_ d: Int) -> String`:

- `d > 0` → `"\(d)"` with subtitle `"days left"`
- `d == 0` → `"0"` with subtitle `"today"`
- `d < 0` → `"\(-d)"` with subtitle `"days ago"`

(Big number is always the magnitude; subtitle carries direction/tense.)

## UI — App

- **Root:** `NavigationStack` with a `List` of events, black background.
  Each row: title (small, gray, monospaced) + delta number (large, white,
  monospaced) + subtitle. Sorted by absolute proximity to today (nearest
  first).
- **Add / Edit:** a sheet with a `TextField` (title) and a `DatePicker`
  (date only). Save writes through `EventStore`.
- **Delete:** swipe to delete.
- **Empty state:** short prompt to add the first event.

Styling: `.preferredColorScheme(.dark)`, black backgrounds, `.monospaced()` /
`Font.system(..., design: .monospaced)` throughout.

## UI — Widget

- **Configurable** via `AppIntentConfiguration`. A `WidgetConfigIntent`
  (AppIntent) exposes two parameters entered directly by the user in the
  long-press configuration UI:
  - `title: String` — event name
  - `date: Date` — target date
  No `EntityQuery`, no shared store.
- **Families:** `.systemSmall`, `.systemMedium`.
- **Content:** black background, large monospaced delta number, small
  monospaced title + subtitle. Same look as the app rows.
- **Timeline:** one entry now; refresh policy `.after(next midnight)` so the
  number is recomputed once per day. Deltas change at most once per day, so no
  finer cadence is needed.
- **Fallback:** if the user hasn't configured a date yet, show a "Set a date"
  placeholder.

## Build / Run

- Switch active toolchain to full Xcode:
  `sudo xcode-select -s /Applications/Xcode.app`.
- Project generated from a declarative `project.yml` via **XcodeGen** (avoids
  hand-editing the `.pbxproj`; reproducible two-target setup).
- Signing: free Apple ID / personal team on both targets. Bundle IDs share the
  team prefix (`com.<you>.daydelta`, `com.<you>.daydelta.widget`). No App Group
  capability needed.
- Build to the connected iPhone; trust the developer cert on-device once.

## Testing

- Unit test for `dayDelta` (future/past/same-day/DST) — assert-based.
- Manual verification: add event, see number in app, add widget to Home
  Screen, long-press → pick event, confirm number matches.

## Open Risks

- Free Apple ID signing: personal-team provisioning expires after 7 days and
  caps active App IDs; fine for personal use, noted for the user.
- Widget events are configured independently from the app list (no sync) — a
  deliberate consequence of dropping the App Group. If the user later wants the
  widget to pick from app events, that requires a paid account + App Group.
