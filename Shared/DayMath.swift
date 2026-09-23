import Foundation

/// Whole-day difference between two dates, each normalized to start-of-day.
/// Positive = target in the future (countdown), negative = past (count-up), 0 = today.
/// Normalizing both to startOfDay first avoids the off-by-one where a sub-24h
/// gap would otherwise round to 0.
func dayDelta(to target: Date, from now: Date = Date(), calendar: Calendar = .current) -> Int {
    let a = calendar.startOfDay(for: now)
    let b = calendar.startOfDay(for: target)
    return calendar.dateComponents([.day], from: a, to: b).day ?? 0
}

/// Big number + subtitle.
/// Future date → countdown ("N" / "days left").
/// Today or past → day-together counter: the start day is day 1, so a date
/// that is `k` days in the past shows day `k + 1` ("N" / "days together").
func deltaText(_ delta: Int) -> (number: String, subtitle: String) {
    if delta > 0 { return ("\(delta)", "days left") }
    return ("\(-delta + 1)", "days together")
}

/// The next time this date's month/day comes around: this year's occurrence, or
/// next year's if this year's has already passed. Used for yearly-repeat events.
/// ponytail: Feb 29 in a non-leap year falls back to whatever Foundation rolls
/// it to (Mar 1) — acceptable for a personal counter.
func nextYearlyOccurrence(of date: Date, from now: Date = Date(), calendar: Calendar = .current) -> Date {
    let md = calendar.dateComponents([.month, .day], from: date)
    let today = calendar.startOfDay(for: now)
    let year = calendar.component(.year, from: today)
    var dc = DateComponents(year: year, month: md.month, day: md.day)
    let thisYear = calendar.startOfDay(for: calendar.date(from: dc)!)
    if thisYear >= today { return thisYear }
    dc.year = year + 1
    return calendar.startOfDay(for: calendar.date(from: dc)!)
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

/// A fixed, sortable date label with weekday, e.g. "2025/09/28 (Sun)".
func dateLabel(_ date: Date, calendar: Calendar = .current, locale: Locale = .current) -> String {
    let f = DateFormatter()
    f.calendar = calendar
    f.timeZone = calendar.timeZone
    f.locale = locale
    f.dateFormat = "yyyy/MM/dd (EEE)"
    return f.string(from: date)
}
