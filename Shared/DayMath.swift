import Foundation

/// Asset names in Shared/EventIcons.xcassets, in picker order. `nil` = no icon.
let eventIconNames = [
    "ic-heart", "ic-star", "ic-cake", "ic-gift", "ic-plane", "ic-flag",
    "ic-book", "ic-briefcase", "ic-ring", "ic-target", "ic-clock", "ic-graduation",
]

/// SF Symbols offered for categories (rendered with Image(systemName:)). ~30 to
/// pick from when creating a custom category.
let categoryIconNames = [
    "fork.knife", "cup.and.saucer.fill", "cart.fill", "bag.fill",
    "car.fill", "bus.fill", "fuelpump.fill", "airplane",
    "house.fill", "bed.double.fill", "bolt.fill", "drop.fill",
    "wifi", "phone.fill", "gamecontroller.fill", "film.fill",
    "music.note", "book.fill", "graduationcap.fill", "pawprint.fill",
    "cross.case.fill", "pills.fill", "dumbbell.fill", "tshirt.fill",
    "scissors", "wrench.and.screwdriver.fill", "gift.fill", "creditcard.fill",
    "dollarsign.circle.fill", "building.columns.fill", "chart.line.uptrend.xyaxis", "briefcase.fill",
    "ellipsis.circle.fill",
]

/// Whole-day difference between two dates, each normalized to start-of-day.
/// Positive = target in the future (countdown), negative = past (count-up), 0 = today.
/// Normalizing both to startOfDay first avoids the off-by-one where a sub-24h
/// gap would otherwise round to 0.
func dayDelta(to target: Date, from now: Date = Date(), calendar: Calendar = .current) -> Int {
    let a = calendar.startOfDay(for: now)
    let b = calendar.startOfDay(for: target)
    return calendar.dateComponents([.day], from: a, to: b).day ?? 0
}

/// How a single event turns its day-delta into text.
/// `auto` = future counts down, past counts up ("N days ago"), 0 = today.
/// `dayCounter` = inclusive "Day N" counter (start day is day 1) for today/past.
enum CountMode: String, Codable, CaseIterable, Sendable {
    case auto
    case dayCounter
}

/// Big number + subtitle for a delta under a given mode.
func countDisplay(delta: Int, mode: CountMode) -> (number: String, subtitle: String) {
    switch mode {
    case .dayCounter:
        if delta > 0 { return ("\(delta)", "days left") } // counter start still ahead
        return ("\(-delta + 1)", "days")                  // Day N, start day = 1
    case .auto:
        if delta > 0 { return ("\(delta)", "days left") }
        if delta < 0 { return ("\(-delta)", "days ago") }
        return ("0", "today")
    }
}

/// How an event's date repeats.
enum Recurrence: String, Codable, CaseIterable, Sendable {
    case none
    case weekly
    case monthly
    case yearly

    var component: Calendar.Component? {
        switch self {
        case .none:    return nil
        case .weekly:  return .weekOfYear
        case .monthly: return .month
        case .yearly:  return .year
        }
    }
}

/// The next occurrence of `date` on/after today under a recurrence rule.
/// `.none` returns the date unchanged; otherwise the anchor is stepped forward
/// by the recurrence unit until it reaches today or later.
/// ponytail: naive forward stepping capped at 1000 iterations — plenty for any
/// personal date range; direct arithmetic isn't worth the edge-case risk.
func nextOccurrence(of date: Date, recurrence: Recurrence,
                    from now: Date = Date(), calendar: Calendar = .current) -> Date {
    guard let unit = recurrence.component else { return date }
    let today = calendar.startOfDay(for: now)
    var d = calendar.startOfDay(for: date)
    var steps = 0
    while d < today, steps < 1000 {
        guard let next = calendar.date(byAdding: unit, value: 1, to: d) else { break }
        d = calendar.startOfDay(for: next)
        steps += 1
    }
    return d
}

/// The next milestone strictly greater than `dayCount`, drawn from multiples of
/// 100 and 365 (whichever comes first), plus how many days away it is.
/// Returns nil for a count-down (dayCount <= 0), where milestones don't apply.
func nextMilestone(dayCount: Int) -> (target: Int, daysAway: Int)? {
    guard dayCount > 0 else { return nil }
    let hundred = (dayCount / 100 + 1) * 100
    let year = (dayCount / 365 + 1) * 365
    let target = min(hundred, year)
    return (target, target - dayCount)
}

/// True when `date` shares today's month and day (an anniversary of it).
func isAnniversaryToday(_ date: Date, today: Date = Date(), calendar: Calendar = .current) -> Bool {
    let a = calendar.dateComponents([.month, .day], from: date)
    let b = calendar.dateComponents([.month, .day], from: today)
    return a.month == b.month && a.day == b.day
}

/// When a reminder should fire: `daysBefore` days before `target`, at `hour`:00.
func notifyDate(target: Date, daysBefore: Int, hour: Int = 9,
                calendar: Calendar = .current) -> Date {
    let day = calendar.date(byAdding: .day, value: -daysBefore,
                            to: calendar.startOfDay(for: target)) ?? target
    return calendar.date(bySettingHour: hour, minute: 0, second: 0, of: day) ?? day
}

/// A fixed, sortable date label with weekday, e.g. "2025/09/28 (Sun)".
func dateLabel(_ date: Date, calendar: Calendar = .current, locale: Locale = .current) -> String {
    let f = DateFormatter()
    f.calendar = calendar
    f.timeZone = calendar.timeZone
    f.locale = locale
    f.dateFormat = "yyyy/MM/dd (EEE)"
    return f.string(from: date)
}
