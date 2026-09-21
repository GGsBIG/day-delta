# DayDelta — Design

**Date:** 2026-09-21

A minimal iOS app that shows the number of days until / since a set of dates,
in an all-black, monospaced "code" aesthetic, with a configurable Home Screen
widget.

## Goals

- Track multiple dated events in a list.
- For each event, show the day delta: countdown if the date is in the future,
  count-up if it is in the past. Direction is automatic, not a stored setting.
- Add events to a Home Screen widget; the user picks which event each widget
  instance shows.
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

One Xcode project, two targets sharing an **App Group**:

1. **DayDelta** (iOS app, SwiftUI) — event list, add / edit / delete.
2. **DayDeltaWidget** (Widget Extension, WidgetKit + SwiftUI + AppIntents) —
   Home Screen widget, small + medium.

App Group (`group.com.<team>.daydelta`) is the shared container. It is the
only supported way for the widget to read the app's data.

### Shared code

A small shared Swift file compiled into **both** targets (via target
membership):

- `Event` model
- `EventStore` (load/save)
- `dayDelta(...)` computation
- Formatting helper (delta → display string)

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

- JSON-encoded `[Event]` stored in the App Group's `UserDefaults`
  (`UserDefaults(suiteName:)`) under one key.
- `EventStore` provides `load() -> [Event]` and `save([Event])`.
- After any mutation in the app, call
  `WidgetCenter.shared.reloadAllTimelines()` so widgets refresh immediately.

> ponytail: JSON in shared UserDefaults, not CoreData/SwiftData. A flat list of
> {title, date} needs nothing more; the widget reads the same suite. Revisit if
> the list grows to hundreds of entries or needs queries.

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

- **Configurable** via `AppIntentConfiguration`. A `SelectEventIntent`
  (AppIntent) exposes an `EventEntity` parameter; an `EntityQuery` lists the
  user's events (read from the same App Group store) so long-pressing the
  widget lets the user pick which event it shows.
- **Families:** `.systemSmall`, `.systemMedium`.
- **Content:** black background, large monospaced delta number, small
  monospaced title + subtitle. Same look as the app rows.
- **Timeline:** one entry now; refresh policy `.after(next midnight)` so the
  number is recomputed once per day. Deltas change at most once per day, so no
  finer cadence is needed.
- **Fallback:** if the configured event was deleted (or none chosen), show the
  nearest upcoming event, or a "No event" placeholder.

## Build / Run

- Switch active toolchain to full Xcode:
  `sudo xcode-select -s /Applications/Xcode.app`.
- Configure App Group + signing (free Apple ID / personal team) on both
  targets. Bundle IDs share the team prefix.
- Build to the connected iPhone; trust the developer cert on-device once.

## Testing

- Unit test for `dayDelta` (future/past/same-day/DST) — assert-based.
- Manual verification: add event, see number in app, add widget to Home
  Screen, long-press → pick event, confirm number matches.

## Open Risks

- Free Apple ID signing: personal-team provisioning expires after 7 days and
  caps active App IDs; fine for personal use, noted for the user.
- App Group entitlement must be enabled on both targets or the widget reads
  empty data — a common first-run failure to watch for.
